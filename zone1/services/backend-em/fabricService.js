const grpc = require('@grpc/grpc-js');
const { connect, signers } = require('@hyperledger/fabric-gateway');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

// --- CONFIGURATION ---
const MSP_ID = 'OrgEMMSP';
const CHANNEL_NAME = 'traceops';
const CHAINCODE_NAME = 'decision';

// --- FONCTION UTILITAIRE MODIFIÉE ---
async function getPrivateKeyPath(keystorePath) {
    const files = await fs.readdir(keystorePath);
    const keyFile = files.find(file => file.endsWith('_sk'));
    if (!keyFile) throw new Error(`Aucun fichier _sk dans ${keystorePath}`);
    return path.join(keystorePath, keyFile);
}

async function createGatewayConnection() {
    const ccpPath = path.resolve(__dirname, 'zone1-write-connection.json');
    const ccp = JSON.parse(await fs.readFile(ccpPath, 'utf8'));

    const peerName = 'peer0.orgem.traceops.local';
    let peerURL = ccp.peers[peerName].url.replace('grpcs://', '');
    
    // Correction Docker (comme tu as fait)
    peerURL = peerURL.replace('localhost', 'peer0.orgem.traceops.local');
    peerURL = peerURL.replace('127.0.0.1', 'peer0.orgem.traceops.local');
    
    const tlsCert = Buffer.from(ccp.peers[peerName].tlsCACerts.pem);

    const certPath = path.resolve(__dirname, 'wallet/cert.pem');
    const credentials = await fs.readFile(certPath); // Buffer du certificat client

    const keystorePath = path.resolve(__dirname, 'wallet/');
    const keyPath = await getPrivateKeyPath(keystorePath);
    const privateKeyBuffer = await fs.readFile(keyPath); // Buffer de la clé (pour mTLS)
    
    // Création de l'objet KeyObject pour le Signer Fabric
    const privateKeySigner = crypto.createPrivateKey(privateKeyBuffer.toString());

    // --- C'EST ICI QUE TOUT SE JOUE (mTLS) ---
    const client = new grpc.Client(
        peerURL,
        grpc.credentials.createSsl(
            tlsCert,           // 1. Certificat racine du serveur (CA)
            privateKeyBuffer,  // 2. Clé privée du client (mTLS) <--- AJOUT IMPORTANT
            credentials        // 3. Certificat du client (mTLS) <--- AJOUT IMPORTANT
        ),
        {
            'grpc.ssl_target_name_override': 'peer0.orgem.traceops.local',
            'grpc.default_authority': 'peer0.orgem.traceops.local' // Parfois nécessaire
        }
    );

    const gateway = connect({
        client,
        identity: { mspId: MSP_ID, credentials }, 
        signer: signers.newPrivateKeySigner(privateKeySigner), // On utilise l'objet crypto ici
        evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
        endorseOptions: () => ({ deadline: Date.now() + 5000 }),
    });
    
    return { gateway, client };
}

// --- FONCTIONS CRUD ---

async function pushData(ID, payload, appHash) {
    const { gateway, client } = await createGatewayConnection();
    try {
        const network = gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);

        console.log(`\nSubmitDecision --> pushData, ID: ${ID}`);

        const payloadString = JSON.stringify(payload);

        await contract.submitTransaction("SubmitDecision", ID, payloadString, appHash);
        
        return { success: true };
    } catch(err) {
        console.log("Error pushing data : ", err)
        throw err
    } finally {
        gateway.close();
        client.close();
    }
}

async function pullData(ID) {
    const { gateway, client } = await createGatewayConnection();
    try {
        const network = gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);

        console.log(`\nQueryDecision --> pullData, ID: ${ID}`);

        const resultBytes = await contract.evaluateTransaction("QueryDecision", ID);
        const resultString = new TextDecoder().decode(resultBytes);
        
        return JSON.parse(resultString);
    } catch(err) {
        console.log("Error pulling data : ", err)
        throw err
    } finally {
        gateway.close();
        client.close();
    }
}

/**
 * Écriture : Appelle SubmitDecision
 * @param {string} decisionID - Unique ID
 * @param {object} payload - Données JSON
 * @param {string} appHash - Hash SHA256 calculé côté application
 */
// async function submitDecision(decisionID, payload, appHash) {
//     const { gateway, client } = await createGatewayConnection();
//     try {
//         const network = gateway.getNetwork(CHANNEL_NAME);
//         const contract = network.getContract(CHAINCODE_NAME);

//         console.log(`\n--> Submit Transaction: SubmitDecision, ID: ${decisionID}`);

//         // On transforme l'objet payload en string JSON pour le Go
//         const payloadString = JSON.stringify(payload);

//         // submitTransaction envoie la donnée à l'orderer et attend le bloc
//         await contract.submitTransaction('SubmitDecision', decisionID, payloadString, appHash);
        
//         console.log('*** Transaction committed successfully');
//         return { success: true };
//     } catch(err) {
//         console.log("Error submiting decision : ", err)
//     } finally {
//         gateway.close();
//         client.close();
//     }
// }

/**
 * Lecture : Appelle QueryDecision
 */
// async function queryDecision(decisionID) {
//     const { gateway, client } = await createGatewayConnection();
//     try {
//         const network = gateway.getNetwork(CHANNEL_NAME);
//         const contract = network.getContract(CHAINCODE_NAME);

//         console.log(`\n--> Evaluate Transaction: QueryDecision, ID: ${decisionID}`);

//         const resultBytes = await contract.evaluateTransaction('QueryDecision', decisionID);
//         const resultString = new TextDecoder().decode(resultBytes);
        
//         return JSON.parse(resultString);
//     } finally {
//         gateway.close();
//         client.close();
//     }
// }

module.exports = { pushData, pullData };