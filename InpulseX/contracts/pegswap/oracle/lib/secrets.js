import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";

const region = process.env.AWS_REGION;
const clientOptions = { region };
const client = new SecretsManagerClient(clientOptions);

const secrets = {};

export const getSecrets = async (name = process.env.SECRET_ID) => {
  if (secrets[name]) return secrets[name];
  const input = { SecretId: name };
  const command = new GetSecretValueCommand(input);
  const response = await client.send(command);
  const secret = JSON.parse(response.SecretString);
  secrets[name] = secret;
  return secret;
};
