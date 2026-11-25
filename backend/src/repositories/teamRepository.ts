
import type {
  ResultSetHeader,
  RowDataPacket,
} from "mysql2/promise";

import pool from "../db";

export type TeamRole = "admin" | "leader" | "staff";

export interface UserRow extends RowDataPacket {
  id: number;
  name: string;
  email: string;
}

export interface TeamMemberRow extends RowDataPacket {
  id: number;
  owner_id: number;
  user_id: number;
  branch_id: number | null;
  role: TeamRole;
  created_at: Date;
  name: string;
  email: string;
  branch_name: string | null;
}

export interface BranchRow extends RowDataPacket {
  id: number;
}

export async function findOwnerById(
  ownerId: number
): Promise<UserRow | null> {
  const [rows] = await pool.execute<UserRow[]>(
    `
      SELECT id, name, email
      FROM users
      WHERE id = ?
      LIMIT 1
    `,
    [ownerId]
  );

  return rows[0] ?? null;
}

export async function findTeamMembers(
  ownerId: number
): Promise<TeamMemberRow[]> {
  const [rows] = await pool.execute<TeamMemberRow[]>(
    `
      SELECT
        tm.id,
        tm.owner_id,
        tm.user_id,
        tm.branch_id,
        tm.role,
        tm.created_at,
        u.name,
        u.email,
        b.name AS branch_name
      FROM team_members tm
      INNER JOIN users u
        ON u.id = tm.user_id
      LEFT JOIN branches b
        ON b.id = tm.branch_id
      WHERE tm.owner_id = ?
      ORDER BY tm.id DESC
    `,
    [ownerId]
  );

  return rows;
}

export async function findUserByEmail(
  email: string
): Promise<UserRow | null> {
  const [rows] = await pool.execute<UserRow[]>(
    `
      SELECT id, name, email
      FROM users
      WHERE email = ?
      LIMIT 1
    `,
    [email]
  );

  return rows[0] ?? null;
}

export async function findBranchById(
  branchId: number,
  ownerId: number
): Promise<BranchRow | null> {
  const [rows] = await pool.execute<BranchRow[]>(
    `
      SELECT id
      FROM branches
      WHERE id = ?
        AND user_id = ?
      LIMIT 1
    `,
    [branchId, ownerId]
  );

  return rows[0] ?? null;
}

export async function findExistingTeamMember(
  ownerId: number,
  userId: number
): Promise<{ id: number } | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `
      SELECT id
      FROM team_members
      WHERE owner_id = ?
        AND user_id = ?
      LIMIT 1
    `,
    [ownerId, userId]
  );

  return rows[0] ? { id: Number(rows[0].id) } : null;
}

export async function insertTeamMember(
  ownerId: number,
  userId: number,
  branchId: number | null
): Promise<number> {
  const [result] = await pool.execute<ResultSetHeader>(
    `
      INSERT INTO team_members (
        owner_id,
        user_id,
        branch_id,
        role
      )
      VALUES (?, ?, ?, 'staff')
    `,
    [ownerId, userId, branchId]
  );

  return result.insertId;
}

export async function findTeamMemberById(
  memberId: number,
  ownerId: number
): Promise<TeamMemberRow | null> {
  const [rows] = await pool.execute<TeamMemberRow[]>(
    `
      SELECT
        tm.id,
        tm.owner_id,
        tm.user_id,
        tm.branch_id,
        tm.role,
        tm.created_at,
        u.name,
        u.email,
        b.name AS branch_name
      FROM team_members tm
      INNER JOIN users u
        ON u.id = tm.user_id
      LEFT JOIN branches b
        ON b.id = tm.branch_id
      WHERE tm.id = ?
        AND tm.owner_id = ?
      LIMIT 1
    `,
    [memberId, ownerId]
  );

  return rows[0] ?? null;
}

export async function updateTeamMemberRole(
  memberId: number,
  ownerId: number,
  role: TeamRole
): Promise<number> {
  const [result] = await pool.execute<ResultSetHeader>(
    `
      UPDATE team_members
      SET role = ?
      WHERE id = ?
        AND owner_id = ?
    `,
    [role, memberId, ownerId]
  );

  return result.affectedRows;
}

export async function deleteTeamMemberById(
  memberId: number,
  ownerId: number
): Promise<number> {
  const [result] = await pool.execute<ResultSetHeader>(
    `
      DELETE FROM team_members
      WHERE id = ?
        AND owner_id = ?
    `,
    [memberId, ownerId]
  );

  return result.affectedRows;
}
