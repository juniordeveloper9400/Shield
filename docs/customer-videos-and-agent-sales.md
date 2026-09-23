# Customer videos and agent sales refresh

Customer Videos in the admin console passes the signed-in staff token to the backend for listing, publishing, ordering and deleting clips. The member app accepts a configured backend even when direct Neon access is absent. Both Flutter home reels refresh every 30 seconds while mounted and on app resume; failed requests retain existing clips and remain retryable. A successful empty result removes unpublished clips.

The partner web app loads the authenticated agent's customers even when persona loading already populated that agent's profile. Team refresh replaces existing records so personal-sales changes reach the team total. Customer records are replaced on successful reads, including an empty result. Failed reads display a retry message and preserve previously loaded customers. Opening the portal or pulling to refresh fetches current records. Responses from before a session reset are discarded.

These changes require rebuilding/redeploying the admin and Flutter clients. Local tests do not establish that a deployed backend or storage service is reachable. Only published, playable video URLs appear in the customer reel. Sales totals rely on approved activations recorded by the backend; these changes do not create sales or change commission rates.
