#!/bin/bash
BASE_URL="http://localhost:10990/api"

echo "=========================================="
echo "  Legacy Monolith — API Test Script"
echo "=========================================="

# ========================== USERS ==========================

echo ""
echo "--- 1. Create User 1 ---"
curl -s -X POST "$BASE_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username":"mario.rossi","email":"mario@example.com","fullName":"Mario Rossi","address":"Via Roma 1, Bari","phone":"+39 080 1234567"}' | jq .

echo ""
echo "--- 2. Create User 2 ---"
curl -s -X POST "$BASE_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username":"lucia.bianchi","email":"lucia@example.com","fullName":"Lucia Bianchi","address":"Via Napoli 42, Lecce","phone":"+39 0832 9876543"}' | jq .

echo ""
echo "--- 3. List all Users ---"
curl -s "$BASE_URL/users" | jq .

echo ""
echo "--- 4. Get User by ID (1) ---"
curl -s "$BASE_URL/users/1" | jq .

echo ""
echo "--- 5. Update User 1 ---"
curl -s -X PUT "$BASE_URL/users/1" \
  -H "Content-Type: application/json" \
  -d '{"username":"mario.rossi","email":"mario.updated@example.com","fullName":"Mario Rossi Updated","address":"Via Milano 10, Bari","phone":"+39 080 0000000"}' | jq .

# ========================== ORDERS ==========================

echo ""
echo "--- 6. Create Order for User 1 ---"
curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"product":"Laptop Dell XPS 15","quantity":1,"totalPrice":1499.99}' | jq .

echo ""
echo "--- 7. Create Order for User 2 ---"
curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"userId":2,"product":"Tastiera Meccanica","quantity":2,"totalPrice":159.90}' | jq .

echo ""
echo "--- 8. Create another Order for User 1 ---"
curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"product":"Monitor 4K 27\"","quantity":1,"totalPrice":549.00}' | jq .

echo ""
echo "--- 9. List all Orders ---"
curl -s "$BASE_URL/orders" | jq .

echo ""
echo "--- 10. Get Orders by User 1 ---"
curl -s "$BASE_URL/orders/user/1" | jq .

echo ""
echo "--- 11. Update Order 1 status to SHIPPED ---"
curl -s -X PUT "$BASE_URL/orders/1/status" \
  -H "Content-Type: application/json" \
  -d '{"status":"SHIPPED"}' | jq .

# ========================== LEGACY DYNAMIC ENDPOINTS ==========================

echo ""
echo "--- 12. Dynamic Business Component (Class.forName) ---"
curl -s "$BASE_URL/legacy/dynamic?operation=processPayment" | jq .

echo ""
echo "--- 13. Dynamic with explicit className ---"
curl -s "$BASE_URL/legacy/dynamic?className=com.cgm.nais.legacy.DynamicBusinessComponent&operation=generateReport" | jq .

echo ""
echo "--- 14. Introspect User 1 (BeanUtils reflection) ---"
curl -s "$BASE_URL/legacy/introspect/user/1" | jq .

echo ""
echo "--- 15. Introspect Order 1 (BeanUtils reflection) ---"
curl -s "$BASE_URL/legacy/introspect/order/1" | jq .

# ========================== ERROR CASES ==========================

echo ""
echo "--- 16. Get non-existent User (404) ---"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$BASE_URL/users/999"

echo ""
echo "--- 17. Create Order for non-existent User (400) ---"
curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"userId":999,"product":"Ghost Product","quantity":1,"totalPrice":0.01}' | jq .

echo ""
echo "--- 18. Dynamic with invalid class (500) ---"
curl -s "$BASE_URL/legacy/dynamic?className=com.does.not.Exist" | jq .

echo ""
echo "=========================================="
echo "  Done!"
echo "=========================================="
