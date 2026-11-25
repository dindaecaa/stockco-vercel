
import { randomUUID } from "node:crypto";
import type { Request, Response, NextFunction } from "express";

import { logger } from "../utils/logger";

declare global {
  namespace Express {
    interface Request {
      requestId?: string;
    }
  }
}

export const requestLoggerMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const requestId = randomUUID();
  const startTime = Date.now();

  req.requestId = requestId;

  res.setHeader("X-Request-ID", requestId);

  logger.info("Request received", {
    requestId,
    method: req.method,
    path: req.originalUrl,
  });

  res.on("finish", () => {
    logger.info("Request completed", {
      requestId,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - startTime,
    });
  });

  next();
};
