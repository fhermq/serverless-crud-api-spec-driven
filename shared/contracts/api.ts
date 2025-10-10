/**
 * API contracts and shared interfaces
 */

import { Item, CreateItemRequest, UpdateItemRequest } from '../models/item';
import { ErrorResponse as ErrorResponseModel } from '../models/error';

// API Gateway event types
export interface APIGatewayEvent {
  httpMethod: string;
  path: string;
  pathParameters: Record<string, string> | null;
  queryStringParameters: Record<string, string> | null;
  headers: Record<string, string>;
  body: string | null;
  requestContext: {
    requestId: string;
    stage: string;
    httpMethod: string;
    path: string;
    accountId: string;
    resourceId: string;
    resourcePath: string;
  };
}

// Lambda response interface
export interface APIGatewayResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

// API endpoint contracts
export namespace ItemAPI {
  // POST /items
  export namespace CreateItem {
    export type RequestBody = CreateItemRequest;
    export type SuccessResponse = Item;
    export type ErrorResponse = ErrorResponseModel;
    export const METHOD = 'POST';
    export const PATH = '/items';
  }

  // GET /items/{id}
  export namespace GetItem {
    export interface PathParameters {
      id: string;
    }
    export type SuccessResponse = Item;
    export type ErrorResponse = ErrorResponseModel;
    export const METHOD = 'GET';
    export const PATH = '/items/{id}';
  }

  // PUT /items/{id}
  export namespace UpdateItem {
    export interface PathParameters {
      id: string;
    }
    export type RequestBody = UpdateItemRequest;
    export type SuccessResponse = Item;
    export type ErrorResponse = ErrorResponseModel;
    export const METHOD = 'PUT';
    export const PATH = '/items/{id}';
  }

  // DELETE /items/{id}
  export namespace DeleteItem {
    export interface PathParameters {
      id: string;
    }
    export type SuccessResponse = void; // 204 No Content
    export type ErrorResponse = ErrorResponseModel;
    export const METHOD = 'DELETE';
    export const PATH = '/items/{id}';
  }
}

// Common response headers
export const COMMON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
} as const;

// Environment variables interface
export interface EnvironmentConfig {
  DYNAMODB_TABLE_NAME: string;
  AWS_REGION: string;
  LOG_LEVEL?: string;
  STAGE?: string;
}

// DynamoDB operation interfaces
export interface DynamoDBItem {
  id: string;
  name: string;
  description?: string;
  category: string;
  price: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateItemInput {
  name: string;
  description?: string;
  category: string;
  price: number;
}

export interface UpdateItemInput {
  name?: string;
  description?: string;
  category?: string;
  price?: number;
}

// Re-export Item from models for convenience
export { Item } from '../models/item';