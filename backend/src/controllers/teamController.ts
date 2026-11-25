
import type { Request, Response } from "express";

import {
  inviteTeamMemberSchema,
  teamMemberIdSchema,
  updateMemberRoleSchema,
} from "../validators/teamValidator";

import {
  changeTeamMemberRole,
  getTeamMembersData,
  inviteTeamMember as inviteTeamMemberService,
  removeTeamMember,
  TeamError,
} from "../services/teamService";

function handleTeamError(
  res: Response,
  error: unknown,
  logMessage: string
): void {
  if (error instanceof TeamError) {
    res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
    return;
  }

  console.error(logMessage, error);

  res.status(500).json({
    success: false,
    message: "Terjadi kesalahan pada server.",
  });
}

// =====================================
// GET TEAM MEMBERS
// GET /api/team
// =====================================

export const getTeamMembers = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const data = await getTeamMembersData(req.userId);

    res.status(200).json({
      success: true,
      message: "Data anggota tim berhasil diambil.",
      data,
    });
  } catch (error) {
    handleTeamError(
      res,
      error,
      "Get team members error:"
    );
  }
};

// =====================================
// INVITE TEAM MEMBER
// POST /api/team/invite
// =====================================

export const inviteTeamMember = async (
  req: Request,
  res: Response
): Promise<void> => {
  const validation = inviteTeamMemberSchema.safeParse(req.body);

  if (!validation.success) {
    res.status(400).json({
      success: false,
      message:
        validation.error.issues[0]?.message ??
        "Data anggota tidak valid.",
    });
    return;
  }

  try {
    const data = await inviteTeamMemberService(
      req.userId,
      validation.data
    );

    res.status(201).json({
      success: true,
      message: "Anggota berhasil ditambahkan ke tim.",
      data,
    });
  } catch (error) {
    handleTeamError(
      res,
      error,
      "Invite team member error:"
    );
  }
};

// =====================================
// UPDATE MEMBER ROLE
// PATCH /api/team/:id/role
// =====================================

export const updateMemberRole = async (
  req: Request,
  res: Response
): Promise<void> => {
  const idValidation = teamMemberIdSchema.safeParse({
    id: req.params.id,
  });

  if (!idValidation.success) {
    res.status(400).json({
      success: false,
      message: "ID anggota tidak valid.",
    });
    return;
  }

  const roleValidation = updateMemberRoleSchema.safeParse(
    req.body
  );

  if (!roleValidation.success) {
    res.status(400).json({
      success: false,
      message:
        roleValidation.error.issues[0]?.message ??
        "Role anggota tidak valid.",
    });
    return;
  }

  try {
    await changeTeamMemberRole(
      req.userId,
      idValidation.data.id,
      roleValidation.data
    );

    res.status(200).json({
      success: true,
      message: "Role anggota berhasil diperbarui.",
    });
  } catch (error) {
    handleTeamError(
      res,
      error,
      "Update member role error:"
    );
  }
};

// =====================================
// DELETE TEAM MEMBER
// DELETE /api/team/:id
// =====================================

export const deleteTeamMember = async (
  req: Request,
  res: Response
): Promise<void> => {
  const validation = teamMemberIdSchema.safeParse({
    id: req.params.id,
  });

  if (!validation.success) {
    res.status(400).json({
      success: false,
      message: "ID anggota tidak valid.",
    });
    return;
  }

  try {
    await removeTeamMember(
      req.userId,
      validation.data.id
    );

    res.status(200).json({
      success: true,
      message: "Anggota berhasil dihapus dari tim.",
    });
  } catch (error) {
    handleTeamError(
      res,
      error,
      "Delete team member error:"
    );
  }
};
