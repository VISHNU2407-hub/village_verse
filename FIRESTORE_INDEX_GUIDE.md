# Firestore Composite Index Setup

## Issue
The Info Feed query requires a composite index on the `posts` collection.

## Required Index Configuration

**Collection:** `posts`

**Fields:**
1. `village` - Ascending
2. `createdAt` - Descending

## Current Query
```dart
_firestore
  .collection('posts')
  .where('village', isEqualTo: village)
  .orderBy('createdAt', descending: true)
  .snapshots();
```

## Steps to Create Index

1. Go to Firebase Console: https://console.firebase.google.com/v1/r/project/village-assistance-app/firestore/indexes

2. Click "Add Index"

3. Configure:
   - Collection ID: `posts`
   - Field 1: `village` (Ascending)
   - Field 2: `createdAt` (Descending)

4. Click "Create"

5. Wait for index to build (usually takes a few minutes)

6. Verify index status is "Enabled"

## Troubleshooting

If the index error persists after creating the index:

1. **Verify field names match exactly:**
   - Firestore field: `village` (lowercase)
   - Firestore field: `createdAt` (camelCase)

2. **Verify index configuration:**
   - village must be Ascending
   - createdAt must be Descending

3. **Check for additional filters:**
   - The query should only have these two clauses
   - No additional where() or orderBy() clauses

4. **Verify collection name:**
   - Collection must be exactly `posts` (lowercase)

## Verification

After creating the index, the Info Feed should load without the index error.
