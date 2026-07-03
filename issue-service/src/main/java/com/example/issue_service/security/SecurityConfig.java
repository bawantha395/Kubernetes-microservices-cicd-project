package com.example.issue_service.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtFilter) {
        this.jwtFilter = jwtFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http.csrf(csrf -> csrf.disable());
        http.sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
        http.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        http.authorizeHttpRequests(auth -> auth
                // 🟢 FIXED: Aligned health probes with gateway pathing
                .requestMatchers("/api/issues/actuator/**").permitAll()
                
                // 🟢 FIXED: Added "/api" prefix across all CRUD transaction layers
                // Both USER and ADMIN can view issues
                .requestMatchers(HttpMethod.GET, "/api/issues/**").hasAnyRole("USER", "ADMIN")
                // Both USER and ADMIN can create issues
                .requestMatchers(HttpMethod.POST, "/api/issues/**").hasAnyRole("USER", "ADMIN")
                // Both USER and ADMIN can update issues
                .requestMatchers(HttpMethod.PUT, "/api/issues/**").hasAnyRole("USER", "ADMIN")
                // Both USER and ADMIN can update status (PATCH)
                .requestMatchers(HttpMethod.PATCH, "/api/issues/**").hasAnyRole("USER", "ADMIN")
                // Both USER and ADMIN can delete issues
                .requestMatchers(HttpMethod.DELETE, "/api/issues/**").hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated()
        );
        return http.build();
    }
}
