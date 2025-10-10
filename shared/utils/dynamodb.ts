/**
 * DynamoDB utilities and helpers
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { 
  DynamoDBDocumentClient, 
  PutCommand, 
  GetCommand, 
  UpdateCommand, 
  DeleteCommand,
  QueryCommand
} from '@aws-sdk/lib-dynamodb';
import { Item, CreateItemInput, UpdateItemInput } from '../contracts/api';
import { generateUUID, generateTimestamp } from './uuid';
import { logger } from './logger';
import { NotFoundError, ApiError } from '../models/error';

// DynamoDB client configuration
const dynamoDBClient = new DynamoDBClient({
  region: process.env.AWS_REGION || 'us-east-1',
  ...(process.env.DYNAMODB_ENDPOINT && {
    endpoint: process.env.DYNAMODB_ENDPOINT
  })
});

const docClient = DynamoDBDocumentClient.from(dynamoDBClient);

const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME || 'serverless-crud-api-items';

/**
 * Create a new item in DynamoDB
 */
export async function createItem(input: CreateItemInput, requestId?: string): Promise<Item> {
  const startTime = Date.now();
  const id = generateUUID();
  const timestamp = generateTimestamp();
  
  const item: Item = {
    id,
    name: input.name,
    ...(input.description !== undefined && { description: input.description }),
    category: input.category,
    price: input.price,
    createdAt: timestamp,
    updatedAt: timestamp
  };

  try {
    logger.debug('Creating item in DynamoDB', { itemId: id, requestId });
    
    const command = new PutCommand({
      TableName: TABLE_NAME,
      Item: item,
      ConditionExpression: 'attribute_not_exists(id)' // Ensure no duplicate IDs
    });

    await docClient.send(command);
    
    const duration = Date.now() - startTime;
    logger.logDatabaseOperation('PUT', TABLE_NAME, { id }, duration);
    logger.info('Item created successfully', { itemId: id, requestId });
    
    return item;
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Failed to create item', error as Error, { 
      itemId: id, 
      requestId,
      duration: `${duration}ms`
    });
    
    if (error instanceof Error && error.name === 'ConditionalCheckFailedException') {
      throw new ApiError('Item with this ID already exists', 409, undefined, requestId);
    }
    
    throw new ApiError('Failed to create item', 500, undefined, requestId);
  }
}

/**
 * Get an item by ID from DynamoDB
 */
export async function getItem(id: string, requestId?: string): Promise<Item> {
  const startTime = Date.now();
  
  try {
    logger.debug('Getting item from DynamoDB', { itemId: id, requestId });
    
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: { id }
    });

    const result = await docClient.send(command);
    
    const duration = Date.now() - startTime;
    logger.logDatabaseOperation('GET', TABLE_NAME, { id }, duration);
    
    if (!result.Item) {
      logger.info('Item not found', { itemId: id, requestId });
      throw new NotFoundError('Item', id, requestId);
    }
    
    logger.info('Item retrieved successfully', { itemId: id, requestId });
    return result.Item as Item;
  } catch (error) {
    const duration = Date.now() - startTime;
    
    if (error instanceof NotFoundError) {
      throw error;
    }
    
    logger.error('Failed to get item', error as Error, { 
      itemId: id, 
      requestId,
      duration: `${duration}ms`
    });
    
    throw new ApiError('Failed to retrieve item', 500, undefined, requestId);
  }
}

/**
 * Update an item in DynamoDB
 */
export async function updateItem(id: string, input: UpdateItemInput, requestId?: string): Promise<Item> {
  const startTime = Date.now();
  const timestamp = generateTimestamp();
  
  try {
    logger.debug('Updating item in DynamoDB', { itemId: id, requestId });
    
    // Build update expression dynamically
    const updateExpressions: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, any> = {};
    
    // Always update the updatedAt timestamp
    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = timestamp;
    
    if (input.name !== undefined) {
      updateExpressions.push('#name = :name');
      expressionAttributeNames['#name'] = 'name';
      expressionAttributeValues[':name'] = input.name;
    }
    
    if (input.description !== undefined) {
      updateExpressions.push('#description = :description');
      expressionAttributeNames['#description'] = 'description';
      expressionAttributeValues[':description'] = input.description;
    }
    
    if (input.category !== undefined) {
      updateExpressions.push('#category = :category');
      expressionAttributeNames['#category'] = 'category';
      expressionAttributeValues[':category'] = input.category;
    }
    
    if (input.price !== undefined) {
      updateExpressions.push('#price = :price');
      expressionAttributeNames['#price'] = 'price';
      expressionAttributeValues[':price'] = input.price;
    }
    
    const command = new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { id },
      UpdateExpression: `SET ${updateExpressions.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ConditionExpression: 'attribute_exists(id)', // Ensure item exists
      ReturnValues: 'ALL_NEW'
    });

    const result = await docClient.send(command);
    
    const duration = Date.now() - startTime;
    logger.logDatabaseOperation('UPDATE', TABLE_NAME, { id }, duration);
    logger.info('Item updated successfully', { itemId: id, requestId });
    
    return result.Attributes as Item;
  } catch (error) {
    const duration = Date.now() - startTime;
    
    if (error instanceof Error && error.name === 'ConditionalCheckFailedException') {
      logger.info('Item not found for update', { itemId: id, requestId });
      throw new NotFoundError('Item', id, requestId);
    }
    
    logger.error('Failed to update item', error as Error, { 
      itemId: id, 
      requestId,
      duration: `${duration}ms`
    });
    
    throw new ApiError('Failed to update item', 500, undefined, requestId);
  }
}

/**
 * Delete an item from DynamoDB
 */
export async function deleteItem(id: string, requestId?: string): Promise<void> {
  const startTime = Date.now();
  
  try {
    logger.debug('Deleting item from DynamoDB', { itemId: id, requestId });
    
    const command = new DeleteCommand({
      TableName: TABLE_NAME,
      Key: { id },
      ConditionExpression: 'attribute_exists(id)', // Ensure item exists
      ReturnValues: 'ALL_OLD'
    });

    const result = await docClient.send(command);
    
    const duration = Date.now() - startTime;
    logger.logDatabaseOperation('DELETE', TABLE_NAME, { id }, duration);
    
    if (!result.Attributes) {
      logger.info('Item not found for deletion', { itemId: id, requestId });
      throw new NotFoundError('Item', id, requestId);
    }
    
    logger.info('Item deleted successfully', { itemId: id, requestId });
  } catch (error) {
    const duration = Date.now() - startTime;
    
    if (error instanceof NotFoundError) {
      throw error;
    }
    
    if (error instanceof Error && error.name === 'ConditionalCheckFailedException') {
      logger.info('Item not found for deletion', { itemId: id, requestId });
      throw new NotFoundError('Item', id, requestId);
    }
    
    logger.error('Failed to delete item', error as Error, { 
      itemId: id, 
      requestId,
      duration: `${duration}ms`
    });
    
    throw new ApiError('Failed to delete item', 500, undefined, requestId);
  }
}

/**
 * Query items by category using GSI
 */
export async function getItemsByCategory(category: string, requestId?: string): Promise<Item[]> {
  const startTime = Date.now();
  
  try {
    logger.debug('Querying items by category', { category, requestId });
    
    const command = new QueryCommand({
      TableName: TABLE_NAME,
      IndexName: 'CategoryIndex',
      KeyConditionExpression: 'category = :category',
      ExpressionAttributeValues: {
        ':category': category
      },
      ScanIndexForward: false // Sort by createdAt descending
    });

    const result = await docClient.send(command);
    
    const duration = Date.now() - startTime;
    logger.logDatabaseOperation('QUERY', TABLE_NAME, { category }, duration);
    logger.info('Items retrieved by category', { 
      category, 
      count: result.Items?.length || 0, 
      requestId 
    });
    
    return (result.Items || []) as Item[];
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Failed to query items by category', error as Error, { 
      category, 
      requestId,
      duration: `${duration}ms`
    });
    
    throw new ApiError('Failed to retrieve items', 500, undefined, requestId);
  }
}

/**
 * Health check for DynamoDB connection
 */
export async function healthCheck(): Promise<boolean> {
  try {
    // Try to describe the table to check connectivity
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: { id: 'health-check-non-existent-id' }
    });
    
    await docClient.send(command);
    return true;
  } catch (error) {
    logger.error('DynamoDB health check failed', error as Error);
    return false;
  }
}