# Voice message Storage access

Voice recordings use the existing Firebase Storage bucket at:

`chats/{chatId}/audio/{senderId}/{localId}.m4a`

The client uploads AAC audio with the `audio/mp4` content type and stores the
resulting download URL in the existing chat message document. This feature does
not add Storage rules or change Firestore authorization.

Before enabling voice messages in a Firebase environment, verify that its
Storage rules:

- Require an authenticated user for reads and writes.
- Allow reads only to authenticated members of the matching
  `chats/{chatId}` conversation.
- Allow creates only to authenticated conversation members, and require the
  `{senderId}` path segment to equal `request.auth.uid`.
- Validate the expected audio content type and enforce an appropriate upload
  size limit.
- Do not grant broader access to the `chats` bucket path through another
  wildcard rule.

The repository does not contain a Firebase Storage rules file, so these checks
must be verified in the Firebase project's existing rules before deployment.
