/**
 * Error response models and utilities
 */

export interface ErrorResponse {
  error: string;
  message: string;
  details?: string[];
  timestamp?: string;
  requestId?: string;
}

export interface ValidationError {
  field: string;
  message: string;
  value?: any;
}

export class ApiError extends Error {
  public statusCode: number;
  public details?: string[];
  public requestId?: string;

  constructor(
    message: string,
    statusCode: number = 500,
    details?: string[],
    requestId?: string
  ) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
    if (details !== undefined) {
      this.details = details;
    }
    if (requestId !== undefined) {
      this.requestId = requestId;
    }
  }
}

export class ValidationApiError extends ApiError {
  public validationErrors: ValidationError[];

  constructor(
    message: string,
    validationErrors: ValidationError[],
    requestId?: string
  ) {
    super(message, 400, validationErrors.map(e => `${e.field}: ${e.message}`), requestId);
    this.name = 'ValidationApiError';
    this.validationErrors = validationErrors;
  }
}

export class NotFoundError extends ApiError {
  constructor(resource: string, id: string, requestId?: string) {
    super(`${resource} with id '${id}' not found`, 404, undefined, requestId);
    this.name = 'NotFoundError';
  }
}

// Standard error responses
export const ERROR_MESSAGES = {
  ITEM_NOT_FOUND: 'Item not found',
  INVALID_REQUEST: 'Invalid request data',
  INTERNAL_SERVER_ERROR: 'Internal server error',
  VALIDATION_FAILED: 'Validation failed',
  UNAUTHORIZED: 'Unauthorized access',
  FORBIDDEN: 'Access forbidden',
  SERVICE_UNAVAILABLE: 'Service temporarily unavailable'
} as const;

// HTTP Status codes
export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503
} as const;