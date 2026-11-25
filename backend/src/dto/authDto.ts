
export interface RegisterDto {
  name: string;
  email: string;
  password: string;
}

export interface LoginDto {
  email: string;
  password: string;
}

export interface UpdateProfileDto {
  name: string;
  email: string;
  phone?: string | null;
}

export interface ChangePasswordDto {
  currentPassword: string;
  newPassword: string;
}

export interface ForgotPasswordDto {
  email: string;
}

export interface VerifyResetCodeDto {
  email: string;
  code: string;
}

export interface ResetPasswordDto {
  resetToken: string;
  newPassword: string;
}

export interface AuthUserDto {
  id: number;
  name: string;
  email: string;
  role: string;
}

export interface AuthResultDto {
  token: string;
  data: AuthUserDto;
}

export interface UserProfileDto {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  profile_photo: string | null;
  role: string | null;
}
