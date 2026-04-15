package com.cgm.nais.resource;

import com.cgm.nais.entity.Order;
import com.cgm.nais.entity.User;
import com.cgm.nais.legacy.DynamicBusinessComponent;
import com.cgm.nais.legacy.LegacyIntrospector;
import com.cgm.nais.service.MonolithService;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Single REST resource that exposes everything — Users, Orders, and legacy dynamic endpoints.
 * This is the "god resource" anti-pattern typical of legacy monoliths.
 */
@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MonolithResource {

    @Inject
    MonolithService service;

    // ========================== USER ENDPOINTS ==========================

    @GET
    @Path("/users")
    public List<User> getAllUsers() {
        return service.listAllUsers();
    }

    @GET
    @Path("/users/{id}")
    public Response getUserById(@PathParam("id") Long id) {
        User user = service.findUserById(id);
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(user).build();
    }

    @POST
    @Path("/users")
    public Response createUser(User user) {
        User created = service.createUser(user);
        return Response.status(Response.Status.CREATED).entity(created).build();
    }

    @PUT
    @Path("/users/{id}")
    public Response updateUser(@PathParam("id") Long id, User user) {
        try {
            User updated = service.updateUser(id, user);
            return Response.ok(updated).build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND).entity(Map.of("error", e.getMessage())).build();
        }
    }

    @DELETE
    @Path("/users/{id}")
    public Response deleteUser(@PathParam("id") Long id) {
        service.deleteUser(id);
        return Response.noContent().build();
    }

    // ========================== ORDER ENDPOINTS ==========================

    @GET
    @Path("/orders")
    public List<Order> getAllOrders() {
        return service.listAllOrders();
    }

    @GET
    @Path("/orders/{id}")
    public Response getOrderById(@PathParam("id") Long id) {
        Order order = service.findOrderById(id);
        if (order == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(order).build();
    }

    @GET
    @Path("/orders/user/{userId}")
    public List<Order> getOrdersByUser(@PathParam("userId") Long userId) {
        return service.findOrdersByUser(userId);
    }

    @POST
    @Path("/orders")
    public Response createOrder(CreateOrderRequest request) {
        try {
            Order order = service.createOrder(
                    request.userId, request.product, request.quantity, request.totalPrice
            );
            return Response.status(Response.Status.CREATED).entity(order).build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.BAD_REQUEST).entity(Map.of("error", e.getMessage())).build();
        }
    }

    @PUT
    @Path("/orders/{id}/status")
    public Response updateOrderStatus(@PathParam("id") Long id, UpdateStatusRequest request) {
        try {
            Order updated = service.updateOrderStatus(id, request.status);
            return Response.ok(updated).build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND).entity(Map.of("error", e.getMessage())).build();
        }
    }

    @DELETE
    @Path("/orders/{id}")
    public Response deleteOrder(@PathParam("id") Long id) {
        service.deleteOrder(id);
        return Response.noContent().build();
    }

    // ========================== LEGACY DYNAMIC ENDPOINT ==========================

    /**
     * Dynamically instantiates a business component using Class.forName().
     * This is the killer for native-image: the class name is provided at runtime
     * and there is no way for GraalVM to know which class to include at build time.
     */
    @GET
    @Path("/legacy/dynamic")
    public Response dynamicBusinessEndpoint(
            @QueryParam("className") @DefaultValue("com.cgm.nais.legacy.DynamicBusinessComponent") String className,
            @QueryParam("operation") @DefaultValue("default") String operation
    ) {
        try {
            // Class.forName() — fatal for native-image without reflect-config.json
            Object instance = LegacyIntrospector.instantiateByName(className);

            if (instance instanceof DynamicBusinessComponent bizComponent) {
                Map<String, Object> result = bizComponent.executeBusinessLogic(operation);
                return Response.ok(result).build();
            }

            // Fallback: deep introspect whatever was loaded
            Map<String, Object> introspection = LegacyIntrospector.deepIntrospect(instance);
            return Response.ok(introspection).build();

        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage()))
                    .build();
        }
    }

    /**
     * Describes any bean using Apache Commons BeanUtils reflection.
     */
    @GET
    @Path("/legacy/introspect/{entityType}/{id}")
    public Response introspectEntity(
            @PathParam("entityType") String entityType,
            @PathParam("id") Long id
    ) {
        Object entity;
        switch (entityType.toLowerCase()) {
            case "user":
                entity = service.findUserById(id);
                break;
            case "order":
                entity = service.findOrderById(id);
                break;
            default:
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "Unknown entity type: " + entityType))
                        .build();
        }

        if (entity == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }

        Map<String, Object> description = LegacyIntrospector.describeBean(entity);
        return Response.ok(description).build();
    }

    // ========================== REQUEST DTOs ==========================

    public static class CreateOrderRequest {
        public Long userId;
        public String product;
        public Integer quantity;
        public BigDecimal totalPrice;
    }

    public static class UpdateStatusRequest {
        public String status;
    }
}
