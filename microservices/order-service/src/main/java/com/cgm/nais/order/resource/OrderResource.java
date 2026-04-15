package com.cgm.nais.order.resource;

import com.cgm.nais.order.entity.Order;
import com.cgm.nais.order.service.OrderService;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Path("/api/orders")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class OrderResource {

    @Inject
    OrderService service;

    @GET
    public List<Order> getAll() {
        return service.listAll();
    }

    @GET
    @Path("/{id}")
    public Response getById(@PathParam("id") Long id) {
        Order order = service.findById(id);
        if (order == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(order).build();
    }

    @GET
    @Path("/user/{userId}")
    public List<Order> getByUser(@PathParam("userId") Long userId) {
        return service.findByUser(userId);
    }

    @POST
    public Response create(CreateOrderRequest request) {
        try {
            Order order = service.createOrder(
                    request.userId, request.product, request.quantity, request.totalPrice
            );
            return Response.status(Response.Status.CREATED).entity(order).build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(Map.of("error", e.getMessage())).build();
        }
    }

    @PUT
    @Path("/{id}/status")
    public Response updateStatus(@PathParam("id") Long id, UpdateStatusRequest request) {
        try {
            Order updated = service.updateStatus(id, request.status);
            return Response.ok(updated).build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(Map.of("error", e.getMessage())).build();
        }
    }

    @DELETE
    @Path("/{id}")
    public Response delete(@PathParam("id") Long id) {
        service.deleteOrder(id);
        return Response.noContent().build();
    }

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
