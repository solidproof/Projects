import { sign } from "./lib/blockchain/eip712.js";
import { writeSignature } from "./lib/db/index.js";
import { chainIds } from "./lib/blockchain/list.js";

export const handler = async ({ body }) => {
  const request = JSON.parse(body);
  if (!request.entry) {
    return {
      statusCode: 400,
      body: "`entry` is required",
    };
  }
  if (!request.blockchain) {
    return {
      statusCode: 400,
      body: "`blockchain` is required",
    };
  }
  if (!chainIds[request.blockchain]) {
    return {
      statusCode: 400,
      body: "`blockchain` is invalid",
    };
  }
  const data = await sign(request);
  await writeSignature(data);
  return {
    statusCode: 200,
    body: JSON.stringify({ abort: true }),
  };
};
