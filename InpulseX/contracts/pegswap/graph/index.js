import { getEvents } from "./lib/db/index.js";

export const handler = async (request) => {
  try {
    return await getEvents(request);
  } catch (error) {
    return { error: error.message };
  }
};
