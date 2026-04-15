package com.cgm.nais.order.client;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * REST Client that calls user-service to validate user existence.
 * Replaces the direct DB coupling of the monolith.
 */
@RegisterRestClient(configKey = "user-service")
@Path("/api/users")
@Produces(MediaType.APPLICATION_JSON)
public interface UserRestClient {

    @GET
    @Path("/{id}")
    UserDto getById(@PathParam("id") Long id);
}
