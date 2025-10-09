/**
 * Item model interface and validation schemas
 */

export interface Item {
  id: string;           // UUID v4
  name: string;         // Required, 1-100 characters
  description?: string; // Optional, max 500 characters
  category: string;     // Required, predefined categories
  price: number;        // Required, positive number
  createdAt: string;    // ISO 8601 timestamp
  updatedAt: string;    // ISO 8601 timestamp
}

export interface CreateItemRequest {
  name: string;
  description?: string;
  category: string;
  price: number;
}

export interface UpdateItemRequest {
  name?: string;
  description?: string;
  category?: string;
  price?: number;
}

export interface ItemResponse {
  id: string;
  name: string;
  description?: string;
  category: string;
  price: number;
  createdAt: string;
  updatedAt: string;
}

// Validation constants
export const VALIDATION_RULES = {
  name: {
    minLength: 1,
    maxLength: 100,
    required: true
  },
  description: {
    maxLength: 500,
    required: false
  },
  category: {
    required: true,
    allowedValues: ['electronics', 'clothing', 'books', 'home', 'sports', 'other']
  },
  price: {
    required: true,
    minimum: 0.01
  }
} as const;

// Type guards
export function isValidCreateItemRequest(obj: any): obj is CreateItemRequest {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.name === 'string' &&
    obj.name.length >= VALIDATION_RULES.name.minLength &&
    obj.name.length <= VALIDATION_RULES.name.maxLength &&
    typeof obj.category === 'string' &&
    VALIDATION_RULES.category.allowedValues.includes(obj.category) &&
    typeof obj.price === 'number' &&
    obj.price >= VALIDATION_RULES.price.minimum &&
    (obj.description === undefined || (typeof obj.description === 'string' && obj.description.length <= VALIDATION_RULES.description.maxLength))
  );
}

export function isValidUpdateItemRequest(obj: any): obj is UpdateItemRequest {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  // At least one field must be provided
  const hasValidField = (
    (obj.name !== undefined && typeof obj.name === 'string' && obj.name.length >= VALIDATION_RULES.name.minLength && obj.name.length <= VALIDATION_RULES.name.maxLength) ||
    (obj.description !== undefined && typeof obj.description === 'string' && obj.description.length <= VALIDATION_RULES.description.maxLength) ||
    (obj.category !== undefined && typeof obj.category === 'string' && VALIDATION_RULES.category.allowedValues.includes(obj.category)) ||
    (obj.price !== undefined && typeof obj.price === 'number' && obj.price >= VALIDATION_RULES.price.minimum)
  );

  return hasValidField;
}