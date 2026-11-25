
import { Router } from "express";

import {
  getTeamMembers,
  inviteTeamMember,
  updateMemberRole,
  deleteTeamMember,
} from "../controllers/teamController";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

router.get("/", getTeamMembers);
router.post("/invite", inviteTeamMember);
router.patch("/:id/role", updateMemberRole);
router.delete("/:id", deleteTeamMember);

export default router;

