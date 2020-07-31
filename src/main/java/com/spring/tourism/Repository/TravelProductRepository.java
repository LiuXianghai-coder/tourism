package com.spring.tourism.Repository;

import com.spring.tourism.Entity.TravelProductEntity;
import org.springframework.data.repository.CrudRepository;

public interface TravelProductRepository extends
        CrudRepository<TravelProductEntity, String> {
    TravelProductEntity getTravelProductEntityByTravelId(String travelId);
}
