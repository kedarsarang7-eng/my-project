# API Contracts

## Base URL
`https://api.dukanx.com/api/v1`

## Authentication

### Login
*   **Endpoint**: `POST /auth/login`
*   **Description**: Authenticate user and return JWT.
*   **Request**:
    ```json
    {
      "email": "owner@example.com",
      "password": "securepassword"
    }
    ```
*   **Response (200)**:
    ```json
    {
      "access_token": "jwt.token.here",
      "token_type": "bearer",
      "user": { "id": "uuid", "role": "owner" }
    }
    ```

## Synchronization

### Push Changes (Desktop -> Cloud)
*   **Endpoint**: `POST /sync/push`
*   **Headers**: `Authorization: Bearer <token>`
*   **Request**:
    ```json
    {
      "business_id": "uuid",
      "customers": [
        {
          "id": "uuid",
          "name": "Updated Name",
          "updated_at": "2023-10-27T12:00:00Z",
          "is_deleted": false
        }
      ],
      "products": [],
      "bills": []
    }
    ```
*   **Response (200)**:
    ```json
    { "status": "success", "synced_count": 5 }
    ```

### Pull Changes (Cloud -> Desktop)
*   **Endpoint**: `POST /sync/pull`
*   **Headers**: `Authorization: Bearer <token>`
*   **Request**:
    ```json
    {
      "business_id": "uuid",
      "last_sync_timestamp": "2023-10-27T08:00:00Z"
    }
    ```
*   **Response (200)**:
    ```json
    {
      "server_timestamp": "2023-10-27T12:05:00Z",
      "customers": [ ... ],
      "products": [ ... ],
      "bills": [ ... ]
    }
    ```

## Business Management

### Get Businesses
*   **Endpoint**: `GET /businesses`
*   **Description**: List businesses owned/managed by the user.
*   **Response**:
    ```json
    [
      { "business_id": "uuid", "name": "My Shop", "role": "owner" }
    ]
    ```
