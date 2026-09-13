import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import * as fs from 'node:fs';
import type { Env } from '../../config/env';
import type { FirebaseVerifier, VerifiedFirebaseToken } from './session.types';

/**
 * Verifies Firebase ID tokens server-side. This is the only place in the
 * system that talks to Firebase Admin — members' phone-auth tokens and
 * staff's email/password tokens both come through here identically.
 * See backend/docs/security.md "Authentication".
 */
@Injectable()
export class FirebaseAdminVerifier implements FirebaseVerifier {
  private readonly logger = new Logger(FirebaseAdminVerifier.name);
  private app: admin.app.App | null = null;

  constructor(private readonly config: ConfigService<Env, true>) {}

  private getApp(): admin.app.App {
    if (this.app) return this.app;

    const projectId = this.config.get('FIREBASE_PROJECT_ID', { infer: true });
    const inlineCreds = this.config.get('FIREBASE_ADMIN_CREDENTIALS', { infer: true });
    const credsFile = this.config.get('FIREBASE_ADMIN_CREDENTIALS_FILE', { infer: true });

    if (!projectId || (!inlineCreds && !credsFile)) {
      throw new Error(
        'Firebase is not configured. Set FIREBASE_PROJECT_ID and either ' +
          'FIREBASE_ADMIN_CREDENTIALS or FIREBASE_ADMIN_CREDENTIALS_FILE.',
      );
    }

    const json = inlineCreds ?? fs.readFileSync(credsFile as string, 'utf-8');
    const serviceAccount = JSON.parse(json) as admin.ServiceAccount;

    this.app = admin.apps.length
      ? (admin.apps[0] as admin.app.App)
      : admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId });

    return this.app;
  }

  async verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken> {
    try {
      const decoded = await admin.auth(this.getApp()).verifyIdToken(idToken);
      return { uid: decoded.uid, email: decoded.email, phoneNumber: decoded.phone_number };
    } catch (err) {
      this.logger.warn(`Firebase token verification failed: ${(err as Error).message}`);
      throw new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } });
    }
  }
}
