// ============================================================================
// COGNITO UTILITIES
// ============================================================================

import {
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminDisableUserCommand,
  AdminEnableUserCommand,
  AdminDeleteUserCommand,
  AdminSetUserPasswordCommand,
  AdminAddUserToGroupCommand,
  AdminRemoveUserFromGroupCommand,
  AdminUpdateUserAttributesCommand,
  GetUserCommand,
  CognitoIdentityProviderClientConfig
} from '@aws-sdk/client-cognito-identity-provider';

const clientConfig: CognitoIdentityProviderClientConfig = {
  region: process.env.AWS_REGION || 'ap-south-1'
};

const cognitoClient = new CognitoIdentityProviderClient(clientConfig);

const USER_POOL_ID = process.env.USER_POOL_ID || '';

export interface CognitoUser {
  username: string;
  userSub: string;
  userStatus: string;
}

export async function adminCreateUser(params: {
  username: string;
  temporaryPassword: string;
  userAttributes: Array<{ Name: string; Value: string }>;
  messageAction?: 'SUPPRESS' | 'RESEND';
}): Promise<CognitoUser> {
  const command = new AdminCreateUserCommand({
    UserPoolId: USER_POOL_ID,
    Username: params.username,
    TemporaryPassword: params.temporaryPassword,
    UserAttributes: params.userAttributes,
    MessageAction: params.messageAction || 'SUPPRESS',
    DesiredDeliveryMediums: []
  });

  const result = await cognitoClient.send(command);
  
  return {
    username: result.User?.Username || params.username,
    userSub: result.User?.Attributes?.find(attr => attr.Name === 'sub')?.Value || '',
    userStatus: result.User?.UserStatus || ''
  };
}

export async function adminDisableUser(username: string): Promise<void> {
  const command = new AdminDisableUserCommand({
    UserPoolId: USER_POOL_ID,
    Username: username
  });

  await cognitoClient.send(command);
}

export async function adminEnableUser(username: string): Promise<void> {
  const command = new AdminEnableUserCommand({
    UserPoolId: USER_POOL_ID,
    Username: username
  });

  await cognitoClient.send(command);
}

export async function adminDeleteUser(username: string): Promise<void> {
  const command = new AdminDeleteUserCommand({
    UserPoolId: USER_POOL_ID,
    Username: username
  });

  await cognitoClient.send(command);
}

export async function adminSetUserPassword(
  username: string, 
  password: string, 
  permanent: boolean
): Promise<void> {
  const command = new AdminSetUserPasswordCommand({
    UserPoolId: USER_POOL_ID,
    Username: username,
    Password: password,
    Permanent: permanent
  });

  await cognitoClient.send(command);
}

export async function adminAddUserToGroup(
  username: string, 
  groupName: string
): Promise<void> {
  const command = new AdminAddUserToGroupCommand({
    UserPoolId: USER_POOL_ID,
    Username: username,
    GroupName: groupName
  });

  await cognitoClient.send(command);
}

export async function adminRemoveUserFromGroup(
  username: string, 
  groupName: string
): Promise<void> {
  const command = new AdminRemoveUserFromGroupCommand({
    UserPoolId: USER_POOL_ID,
    Username: username,
    GroupName: groupName
  });

  await cognitoClient.send(command);
}

export async function adminUpdateUserAttributes(
  username: string,
  attributes: Array<{ Name: string; Value: string }>
): Promise<void> {
  const command = new AdminUpdateUserAttributesCommand({
    UserPoolId: USER_POOL_ID,
    Username: username,
    UserAttributes: attributes
  });

  await cognitoClient.send(command);
}

export async function getUserByAccessToken(accessToken: string): Promise<{
  sub: string;
  email?: string;
  attributes: Record<string, string>;
}> {
  const command = new GetUserCommand({
    AccessToken: accessToken
  });

  const result = await cognitoClient.send(command);
  
  const attributes: Record<string, string> = {};
  result.UserAttributes?.forEach(attr => {
    if (attr.Name && attr.Value) {
      attributes[attr.Name] = attr.Value;
    }
  });

  return {
    sub: attributes['sub'] || '',
    email: attributes['email'],
    attributes
  };
}
