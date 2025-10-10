/**
 * Validation utilities for item data
 */

import { 
  CreateItemRequest, 
  UpdateItemRequest, 
  VALIDATION_RULES,
  isValidCreateItemRequest,
  isValidUpdateItemRequest
} from '../models/item';
import { ValidationError, ValidationApiError } from '../models/error';

/**
 * Validate create item request data
 */
export function validateCreateItemRequest(data: any, requestId?: string): CreateItemRequest {
  const errors: ValidationError[] = [];

  // Check if data exists
  if (!data || typeof data !== 'object') {
    errors.push({
      field: 'body',
      message: 'Request body is required and must be an object'
    });
    throw new ValidationApiError('Invalid request data', errors, requestId);
  }

  // Validate name
  if (!data.name) {
    errors.push({
      field: 'name',
      message: 'Name is required',
      value: data.name
    });
  } else if (typeof data.name !== 'string') {
    errors.push({
      field: 'name',
      message: 'Name must be a string',
      value: data.name
    });
  } else if (data.name.trim().length < VALIDATION_RULES.name.minLength) {
    errors.push({
      field: 'name',
      message: `Name must be at least ${VALIDATION_RULES.name.minLength} character long`,
      value: data.name
    });
  } else if (data.name.length > VALIDATION_RULES.name.maxLength) {
    errors.push({
      field: 'name',
      message: `Name must not exceed ${VALIDATION_RULES.name.maxLength} characters`,
      value: data.name
    });
  }

  // Validate description (optional)
  if (data.description !== undefined) {
    if (typeof data.description !== 'string') {
      errors.push({
        field: 'description',
        message: 'Description must be a string',
        value: data.description
      });
    } else if (data.description.length > VALIDATION_RULES.description.maxLength) {
      errors.push({
        field: 'description',
        message: `Description must not exceed ${VALIDATION_RULES.description.maxLength} characters`,
        value: data.description
      });
    }
  }

  // Validate category
  if (!data.category) {
    errors.push({
      field: 'category',
      message: 'Category is required',
      value: data.category
    });
  } else if (typeof data.category !== 'string') {
    errors.push({
      field: 'category',
      message: 'Category must be a string',
      value: data.category
    });
  } else if (!VALIDATION_RULES.category.allowedValues.includes(data.category)) {
    errors.push({
      field: 'category',
      message: `Category must be one of: ${VALIDATION_RULES.category.allowedValues.join(', ')}`,
      value: data.category
    });
  }

  // Validate price
  if (data.price === undefined || data.price === null) {
    errors.push({
      field: 'price',
      message: 'Price is required',
      value: data.price
    });
  } else if (typeof data.price !== 'number') {
    errors.push({
      field: 'price',
      message: 'Price must be a number',
      value: data.price
    });
  } else if (isNaN(data.price)) {
    errors.push({
      field: 'price',
      message: 'Price must be a valid number',
      value: data.price
    });
  } else if (data.price < VALIDATION_RULES.price.minimum) {
    errors.push({
      field: 'price',
      message: `Price must be at least ${VALIDATION_RULES.price.minimum}`,
      value: data.price
    });
  }

  // Check for unexpected fields
  const allowedFields = ['name', 'description', 'category', 'price'];
  const unexpectedFields = Object.keys(data).filter(key => !allowedFields.includes(key));
  if (unexpectedFields.length > 0) {
    errors.push({
      field: 'body',
      message: `Unexpected fields: ${unexpectedFields.join(', ')}`,
      value: unexpectedFields
    });
  }

  if (errors.length > 0) {
    throw new ValidationApiError('Validation failed', errors, requestId);
  }

  // Use type guard as final validation
  if (!isValidCreateItemRequest(data)) {
    throw new ValidationApiError('Invalid request data format', [{
      field: 'body',
      message: 'Request data does not match expected format'
    }], requestId);
  }

  return data as CreateItemRequest;
}

/**
 * Validate update item request data
 */
export function validateUpdateItemRequest(data: any, requestId?: string): UpdateItemRequest {
  const errors: ValidationError[] = [];

  // Check if data exists
  if (!data || typeof data !== 'object') {
    errors.push({
      field: 'body',
      message: 'Request body is required and must be an object'
    });
    throw new ValidationApiError('Invalid request data', errors, requestId);
  }

  // Check if at least one field is provided
  const providedFields = Object.keys(data).filter(key => 
    ['name', 'description', 'category', 'price'].includes(key) && data[key] !== undefined
  );
  
  if (providedFields.length === 0) {
    errors.push({
      field: 'body',
      message: 'At least one field (name, description, category, price) must be provided for update'
    });
  }

  // Validate name (if provided)
  if (data.name !== undefined) {
    if (typeof data.name !== 'string') {
      errors.push({
        field: 'name',
        message: 'Name must be a string',
        value: data.name
      });
    } else if (data.name.trim().length < VALIDATION_RULES.name.minLength) {
      errors.push({
        field: 'name',
        message: `Name must be at least ${VALIDATION_RULES.name.minLength} character long`,
        value: data.name
      });
    } else if (data.name.length > VALIDATION_RULES.name.maxLength) {
      errors.push({
        field: 'name',
        message: `Name must not exceed ${VALIDATION_RULES.name.maxLength} characters`,
        value: data.name
      });
    }
  }

  // Validate description (if provided)
  if (data.description !== undefined) {
    if (typeof data.description !== 'string') {
      errors.push({
        field: 'description',
        message: 'Description must be a string',
        value: data.description
      });
    } else if (data.description.length > VALIDATION_RULES.description.maxLength) {
      errors.push({
        field: 'description',
        message: `Description must not exceed ${VALIDATION_RULES.description.maxLength} characters`,
        value: data.description
      });
    }
  }

  // Validate category (if provided)
  if (data.category !== undefined) {
    if (typeof data.category !== 'string') {
      errors.push({
        field: 'category',
        message: 'Category must be a string',
        value: data.category
      });
    } else if (!VALIDATION_RULES.category.allowedValues.includes(data.category)) {
      errors.push({
        field: 'category',
        message: `Category must be one of: ${VALIDATION_RULES.category.allowedValues.join(', ')}`,
        value: data.category
      });
    }
  }

  // Validate price (if provided)
  if (data.price !== undefined) {
    if (typeof data.price !== 'number') {
      errors.push({
        field: 'price',
        message: 'Price must be a number',
        value: data.price
      });
    } else if (isNaN(data.price)) {
      errors.push({
        field: 'price',
        message: 'Price must be a valid number',
        value: data.price
      });
    } else if (data.price < VALIDATION_RULES.price.minimum) {
      errors.push({
        field: 'price',
        message: `Price must be at least ${VALIDATION_RULES.price.minimum}`,
        value: data.price
      });
    }
  }

  // Check for unexpected fields
  const allowedFields = ['name', 'description', 'category', 'price'];
  const unexpectedFields = Object.keys(data).filter(key => !allowedFields.includes(key));
  if (unexpectedFields.length > 0) {
    errors.push({
      field: 'body',
      message: `Unexpected fields: ${unexpectedFields.join(', ')}`,
      value: unexpectedFields
    });
  }

  if (errors.length > 0) {
    throw new ValidationApiError('Validation failed', errors, requestId);
  }

  // Use type guard as final validation
  if (!isValidUpdateItemRequest(data)) {
    throw new ValidationApiError('Invalid request data format', [{
      field: 'body',
      message: 'Request data does not match expected format'
    }], requestId);
  }

  return data as UpdateItemRequest;
}

/**
 * Validate item ID format (UUID v4)
 */
export function validateItemId(id: string, requestId?: string): string {
  if (!id || typeof id !== 'string') {
    throw new ValidationApiError('Invalid item ID', [{
      field: 'id',
      message: 'Item ID is required and must be a string',
      value: id
    }], requestId);
  }

  // UUID v4 regex pattern
  const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  
  if (!uuidV4Regex.test(id)) {
    throw new ValidationApiError('Invalid item ID format', [{
      field: 'id',
      message: 'Item ID must be a valid UUID v4',
      value: id
    }], requestId);
  }

  return id;
}

/**
 * Sanitize string input by trimming whitespace
 */
export function sanitizeString(value: string): string {
  return value.trim();
}

/**
 * Sanitize create item request data
 */
export function sanitizeCreateItemRequest(data: CreateItemRequest): CreateItemRequest {
  const sanitized: CreateItemRequest = {
    name: sanitizeString(data.name),
    category: sanitizeString(data.category),
    price: data.price
  };
  
  if (data.description !== undefined) {
    sanitized.description = sanitizeString(data.description);
  }
  
  return sanitized;
}

/**
 * Sanitize update item request data
 */
export function sanitizeUpdateItemRequest(data: UpdateItemRequest): UpdateItemRequest {
  const sanitized: UpdateItemRequest = {};
  
  if (data.name !== undefined) {
    sanitized.name = sanitizeString(data.name);
  }
  if (data.description !== undefined) {
    sanitized.description = sanitizeString(data.description);
  }
  if (data.category !== undefined) {
    sanitized.category = sanitizeString(data.category);
  }
  if (data.price !== undefined) {
    sanitized.price = data.price;
  }
  
  return sanitized;
}