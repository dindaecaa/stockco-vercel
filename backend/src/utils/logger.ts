
type LogLevel = "INFO" | "WARN" | "ERROR";

type LogMetadata = Record<string, unknown>;

function writeLog(
  level: LogLevel,
  message: string,
  metadata: LogMetadata = {}
): void {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...metadata,
  };

  const output = JSON.stringify(logEntry);

  switch (level) {
    case "INFO":
      console.log(output);
      break;

    case "WARN":
      console.warn(output);
      break;

    case "ERROR":
      console.error(output);
      break;
  }
}

export const logger = {
  info(message: string, metadata?: LogMetadata): void {
    writeLog("INFO", message, metadata);
  },

  warn(message: string, metadata?: LogMetadata): void {
    writeLog("WARN", message, metadata);
  },

  error(message: string, metadata?: LogMetadata): void {
    writeLog("ERROR", message, metadata);
  },
};
