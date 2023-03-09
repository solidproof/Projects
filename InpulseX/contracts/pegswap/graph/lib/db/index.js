import { MongoClient } from "mongodb";
import { getSecrets } from "../secrets.js";

const options = {
  useUnifiedTopology: true,
  useNewUrlParser: true,
};

let cachedClient;

const connect = async (retries = 5) => {
  if (cachedClient) {
    return cachedClient;
  }
  const { MONGODB_URI } = await getSecrets("secrets/inpulsex/db");
  while (retries--) {
    try {
      const connection = new MongoClient(MONGODB_URI, options);
      const client = await connection.connect();
      cachedClient = client;
      return client;
    } catch (error) {
      if (!retries) {
        throw error;
      }
    }
  }
};

export const getDB = async () => {
  const client = await connect();
  const { DB_NAME } = await getSecrets("secrets/inpulsex/db");
  return client.db(DB_NAME);
};

export const getEvents = async (request) => {
  const db = await getDB();

  const collection = db.collection("inpulsexPegSwap");

  const query = {};

  if (request.arguments.fromChain) {
    query["request.fromChain"] = request.arguments.fromChain;
  }

  if (request.arguments.toChain) {
    query["request.toChain"] = request.arguments.toChain;
  }

  if (request.arguments.operator) {
    query["request.operator"] = request.arguments.operator;
  }

  if (request.arguments.recipient) {
    query["request.recipient"] = request.arguments.recipient;
  }

  if (request.arguments.amount) {
    query["request.amount"] = request.arguments.amount;
  }

  if (request.arguments.nonce) {
    query["request.nonce"] = request.arguments.nonce;
  }

  return await collection.find(query).toArray();
};
