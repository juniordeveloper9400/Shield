import type { FirebaseVerifier, VerifiedFirebaseToken } from '../../src/modules/auth/session.types';

/** Stands in for real Firebase Admin verification in tests — no real Firebase project needed. */
export class FakeFirebaseVerifier implements FirebaseVerifier {
  private readonly tokens = new Map<string, VerifiedFirebaseToken>();

  register(idToken: string, decoded: VerifiedFirebaseToken) {
    this.tokens.set(idToken, decoded);
  }

  async verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken> {
    const decoded = this.tokens.get(idToken);
    if (!decoded) throw new Error(`FakeFirebaseVerifier: no token registered for "${idToken}"`);
    return decoded;
  }
}
