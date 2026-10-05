export type AdminRole = 'SUPERADMIN' | 'ADMIN' | 'PHARMACY' | 'LAB' | 'APPOINTMENTS' | 'DELIVERY' | 'LAB_TECHNICIAN';
export type SubjectType = 'MEMBER' | 'STAFF';

/** What AuthGuard attaches to the request after verifying a session. */
export interface RequestSubject {
  sessionId: string;
  subjectType: SubjectType;
  subjectId: string; // app.users.id / app.admin_user.id, as a string (bigint-safe)
  role?: AdminRole; // present only when subjectType === 'STAFF'
  storeId?: number | null; // branch scope, staff only
}

export interface IssuedTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number; // seconds
}

export interface VerifiedFirebaseToken {
  uid: string;
  email?: string;
  phoneNumber?: string;
  /** Unix seconds of the sign-in that minted this token (Firebase `auth_time`). */
  authTime?: number;
}

/** Injection token for the Firebase verifier — real impl vs. test fake. */
export const FIREBASE_VERIFIER = Symbol('FIREBASE_VERIFIER');

export interface FirebaseVerifier {
  verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken>;
}
