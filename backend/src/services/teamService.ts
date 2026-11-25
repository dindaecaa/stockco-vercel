
import {
  deleteTeamMemberById,
  findBranchById,
  findExistingTeamMember,
  findOwnerById,
  findTeamMemberById,
  findTeamMembers,
  findUserByEmail,
  insertTeamMember,
  updateTeamMemberRole,
} from "../repositories/teamRepository";

import type { TeamRole } from "../repositories/teamRepository";

import type {
  InviteTeamMemberInput,
  UpdateMemberRoleInput,
} from "../validators/teamValidator";

const OWNER_ACCOUNT_ID = 8;

export class TeamError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = "TeamError";
    this.statusCode = statusCode;
  }
}

function validateOwnerAccess(userId: number | undefined): number {
  if (
    typeof userId !== "number" ||
    !Number.isSafeInteger(userId) ||
    userId <= 0
  ) {
    throw new TeamError(
      "Autentikasi diperlukan.",
      401
    );
  }

  if (userId !== OWNER_ACCOUNT_ID) {
    throw new TeamError(
      "Hanya Owner yang dapat mengelola anggota tim.",
      403
    );
  }

  return OWNER_ACCOUNT_ID;
}

function isDuplicateEntry(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "ER_DUP_ENTRY"
  );
}

export async function getTeamMembersData(
  userId: number | undefined
) {
  const ownerId = validateOwnerAccess(userId);

  const owner = await findOwnerById(ownerId);

  if (!owner) {
    throw new TeamError(
      "Akun pemilik tidak ditemukan.",
      404
    );
  }

  const members = await findTeamMembers(ownerId);

  return {
    owner: {
      id: owner.id,
      name: owner.name,
      email: owner.email,
      role: "owner" as const,
    },
    members,
    total: members.length + 1,
  };
}

export async function inviteTeamMember(
  userId: number | undefined,
  input: InviteTeamMemberInput
) {
  const ownerId = validateOwnerAccess(userId);

  const member = await findUserByEmail(input.email);

  if (!member) {
    throw new TeamError(
      "Akun dengan email tersebut belum terdaftar di Stock.co.",
      404
    );
  }

  if (member.id === ownerId) {
    throw new TeamError(
      "Akun Owner tidak dapat ditambahkan sebagai anggota.",
      400
    );
  }

  const branchId = input.branch_id ?? null;

  if (branchId !== null) {
    const branch = await findBranchById(branchId, ownerId);

    if (!branch) {
      throw new TeamError(
        "Cabang tidak ditemukan atau bukan milik Owner.",
        404
      );
    }
  }

  const existingMember = await findExistingTeamMember(
    ownerId,
    member.id
  );

  if (existingMember) {
    throw new TeamError(
      "Anggota tersebut sudah tergabung dalam tim.",
      409
    );
  }

  try {
    const newMemberId = await insertTeamMember(
      ownerId,
      member.id,
      branchId
    );

    const newMember = await findTeamMemberById(
      newMemberId,
      ownerId
    );

    if (!newMember) {
      throw new TeamError(
        "Anggota berhasil disimpan, tetapi gagal mengambil datanya.",
        500
      );
    }

    return newMember;
  } catch (error) {
    if (error instanceof TeamError) {
      throw error;
    }

    if (isDuplicateEntry(error)) {
      throw new TeamError(
        "Anggota tersebut sudah tergabung dalam tim.",
        409
      );
    }

    throw error;
  }
}

export async function changeTeamMemberRole(
  userId: number | undefined,
  memberId: number,
  input: UpdateMemberRoleInput
) {
  const ownerId = validateOwnerAccess(userId);

  const affectedRows = await updateTeamMemberRole(
    memberId,
    ownerId,
    input.role as TeamRole
  );

  if (affectedRows === 0) {
    const existingMember = await findTeamMemberById(
      memberId,
      ownerId
    );

    if (!existingMember) {
      throw new TeamError(
        "Anggota tidak ditemukan.",
        404
      );
    }
  }
}

export async function removeTeamMember(
  userId: number | undefined,
  memberId: number
) {
  const ownerId = validateOwnerAccess(userId);

  const affectedRows = await deleteTeamMemberById(
    memberId,
    ownerId
  );

  if (affectedRows === 0) {
    throw new TeamError(
      "Anggota tidak ditemukan.",
      404
    );
  }
}
