import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

// --- FUNCIÓN PARA CREAR USUARIOS ---
export const createUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const callerUid = request.auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  if (callerDoc.data()?.role !== "administrador") {
    throw new HttpsError("permission-denied", "No tienes permisos.");
  }
  const {email, password, fullName, role} = request.data;
  if (!(email && password && fullName && role)) {
    throw new HttpsError("invalid-argument", "Faltan datos.");
  }
  try {
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: fullName,
    });
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      email: email,
      fullName: fullName,
      role: role,
      uid: userRecord.uid,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {success: true, message: `Usuario ${fullName} creado con éxito.`};
  } catch (error) {
    logger.error("Error al crear usuario:", error);
    if (error instanceof Error) {
      throw new HttpsError("internal", error.message);
    }
    throw new HttpsError("internal", "Ocurrió un error desconocido.");
  }
});

// --- FUNCIÓN PARA ELIMINAR UN USUARIO ---
export const deleteUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const callerUid = request.auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  if (callerDoc.data()?.role !== "administrador") {
    throw new HttpsError("permission-denied", "No tienes permisos para eliminar usuarios.");
  }

  const {userIdToDelete} = request.data;
  if (!userIdToDelete) {
    throw new HttpsError("invalid-argument", "Falta el ID del usuario a eliminar.");
  }

  try {
    logger.info(`Admin ${callerUid} está eliminando al usuario ${userIdToDelete}`);
    await admin.auth().deleteUser(userIdToDelete);
    await admin.firestore().collection("users").doc(userIdToDelete).delete();
    return {success: true, message: "Usuario eliminado correctamente."};
  } catch (error) {
    logger.error(`Error al eliminar usuario ${userIdToDelete}:`, error);
    if (error instanceof Error) {
      throw new HttpsError("internal", error.message);
    }
    throw new HttpsError("internal", "Ocurrió un error desconocido.");
  }
});


// --- FUNCIÓN PARA ENVIAR NOTIFICACIONES ---
export const onProjectStatusUpdate = onDocumentUpdated("projects/{projectId}", async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!beforeData || !afterData || beforeData.status === afterData.status) {
    return null;
  }

  const newStatus = afterData.status;
  const projectName = afterData.projectName;
  
  let title = "Actualización de tu Proyecto";
  let body = `El proyecto '${projectName}' ha cambiado su estado a: ${newStatus.replace(/_/g, " ")}.`;
  let targetUids: string[] = [];

  switch (newStatus) {
    case "presupuesto_aceptado":
    case "reclamado":
      title = "Proyecto Requiere Acción";
      body = `El proyecto '${projectName}' ahora está en estado '${newStatus}'.`;
      const admins = await admin.firestore().collection("users").where("role", "==", "administrador").get();
      admins.forEach((doc) => targetUids.push(doc.id));
      break;
    
    case "asignado":
      if (afterData.carpenterId) {
        title = "¡Nuevo Proyecto Asignado!";
        body = `Se te ha asignado el proyecto '${projectName}'.`;
        targetUids.push(afterData.carpenterId);
      }
      break;

    default:
      if (afterData.clientId) {
        targetUids.push(afterData.clientId);
      }
      break;
  }

  if (targetUids.length === 0) {
    return null;
  }
  
  const tokens: string[] = [];
  for (const uid of targetUids) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) {
      tokens.push(fcmToken);
    }
  }

  if (tokens.length === 0) {
    return null;
  }

  const notificationPayload = {title, body, sound: "default"};
  const androidConfig: admin.messaging.AndroidConfig = {
    priority: "high",
  };

  try {
    await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      notification: notificationPayload,
      android: androidConfig,
    });
    return {success: true};
  } catch (error) {
    logger.error("Error al enviar notificación:", error);
    return {success: false};
  }
});