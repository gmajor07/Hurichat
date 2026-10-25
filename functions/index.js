const admin = require("firebase-admin");
const functions = require("firebase-functions");

admin.initializeApp();

exports.sendChatMessageNotification = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const message = snapshot.data() || {};
      const chatId = context.params.chatId;
      const messageId = context.params.messageId;
      const senderId = message.senderId;
      const receiverId = message.receiverId;
      const messageText = (message.text || "").trim();

      if (!senderId || !receiverId || senderId === receiverId) {
        return null;
      }

      const [receiverDoc, senderDoc] = await Promise.all([
        admin.firestore().collection("users").doc(receiverId).get(),
        admin.firestore().collection("users").doc(senderId).get(),
      ]);

      if (!receiverDoc.exists) {
        functions.logger.warn("Receiver user document not found", {receiverId});
        return null;
      }

      const receiverData = receiverDoc.data() || {};
      const senderData = senderDoc.data() || {};
      const tokenSet = new Set();
      const rawTokens = Array.isArray(receiverData.fcmTokens) ?
        receiverData.fcmTokens :
        [];

      rawTokens.forEach((token) => {
        if (typeof token === "string" && token.length > 0) {
          tokenSet.add(token);
        }
      });

      if (typeof receiverData.fcmToken === "string" &&
          receiverData.fcmToken.length > 0) {
        tokenSet.add(receiverData.fcmToken);
      }

      const tokens = Array.from(tokenSet);

      if (tokens.length === 0) {
        functions.logger.info("Receiver has no FCM tokens", {receiverId});
        return null;
      }

      const senderName = senderData.name || "New message";
      const body = messageText || "Sent you a message";

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: senderName,
          body,
        },
        data: {
          type: "chat_message",
          chatId,
          messageId,
          title: String(senderName),
          body: String(body),
          senderId: String(senderId),
          receiverId: String(receiverId),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (!result.success) {
          const code = result.error && result.error.code;
          if (code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered") {
            invalidTokens.push(tokens[index]);
          }
          functions.logger.error("Failed to send chat notification", {
            receiverId,
            token: tokens[index],
            error: result.error ? result.error.message : "unknown error",
          });
        }
      });

      if (invalidTokens.length > 0) {
        await admin.firestore().collection("users").doc(receiverId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
      }

      return null;
    });
