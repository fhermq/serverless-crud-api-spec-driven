/**
 * HTTP response utilities for Lambda functions
 */

import { ErrorResponse, HTTP_STATUS } from '../models/error';

export interface LambdaResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

const DEFAULT_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

/**
 * Create a successful response
 */
export function successResponse(
  data: any,
  statusCode: number = HTTP_STATUS.OK,
  additionalHeaders: Record<string, string> = {}
): LambdaResponse {
  return {
    statusCode,
    headers: { ...DEFAULT_HEADERS, ...additionalHeaders },
    body: JSON.stringify(data)
  };
}

/**
 * Create an error response
 */
export function errorResponse(
  error: string,
  message: string,
  statusCode: number = HTTP_STATUS.INTERNAL_SERVER_ERROR,
  details?: string[],
  requestId?: string,
  additionalHeaders: Record<string, string> = {}
): LambdaResponse {
  const errorBody: ErrorResponse = {
    error,
    message,
    ...(details && { details }),
    ...(requestId && { requestId }),
    timestamp: new Date().toISOString()
  };

  return {
    statusCode,
    headers: { ...DEFAULT_HEADERS, ...additionalHeaders },
    body: JSON.stringify(errorBody)
  };
}

/**
 * Create a validation error response
 */
export function validationErrorResponse(
  message: string,
  details: string[],
  requestId?: string
): LambdaResponse {
  return errorResponse(
    'Validation Error',
    message,
    HTTP_STATUS.BAD_REQUEST,
    details,
    requestId
  );
}

/**
 * Create a not found error response
 */
export function notFoundResponse(
  resource: string,
  id: string,
  requestId?: string
): LambdaResponse {
  return errorResponse(
    'Not Found',
    `${resource} with id '${id}' not found`,
    HTTP_STATUS.NOT_FOUND,
    undefined,
    requestId
  );
}

/**
 * Create an internal server error response
 */
export function internalServerErrorResponse(
  message: string = 'An internal server error occurred',
  requestId?: string
): LambdaResponse {
  return errorResponse(
    'Internal Server Error',
    message,
    HTTP_STATUS.INTERNAL_SERVER_ERROR,
    undefined,
    requestId
  );
}

/**
 * Create a created response (201)
 */
export function createdResponse(
  data: any,
  additionalHeaders: Record<string, string> = {}
): LambdaResponse {
  return successResponse(data, HTTP_STATUS.CREATED, additionalHeaders);
}

/**
 * Create a no content response (204)
 */
export function noContentResponse(
  additionalHeaders: Record<string, string> = {}
): LambdaResponse {
  return {
    statusCode: HTTP_STATUS.NO_CONTENT,
    headers: { ...DEFAULT_HEADERS, ...additionalHeaders },
    body: ''
  };
}