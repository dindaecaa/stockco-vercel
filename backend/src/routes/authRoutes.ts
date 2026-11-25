
import { Router } from "express";

import {
  register,
  login,
  getProfile,
  updateProfile,
  uploadProfilePhoto,
  changePassword,
  forgotPassword,
  verifyResetCode,
  resetPassword,
} from "../controllers/authController";

import { authMiddleware } from "../middleware/authMiddleware";
import { uploadProfilePhoto as uploadProfileMiddleware } from "../middleware/uploadProfileMiddleware";

const router = Router();

// REGISTER & LOGIN
router.post("/register", register);
router.post("/login", login);

// PROFILE
router.get("/profile", authMiddleware, getProfile);

router.put(
  "/profile",
  authMiddleware,
  updateProfile
);

// UPLOAD PROFILE PHOTO
router.post(
  "/profile/photo",
  authMiddleware,
  uploadProfileMiddleware,
  uploadProfilePhoto
);

// CHANGE PASSWORD
router.put(
  "/change-password",
  authMiddleware,
  changePassword
);

// FORGOT PASSWORD
router.post("/forgot-password", forgotPassword);
router.post("/verify-reset-code", verifyResetCode);
router.post("/reset-password", resetPassword);

export default router;
