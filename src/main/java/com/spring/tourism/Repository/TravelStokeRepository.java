package com.spring.tourism.Repository;

import com.spring.tourism.Entity.TravelStokeEntity;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface TravelStokeRepository extends CrudRepository<TravelStokeEntity, String> {
    @Modifying
    @Transactional
    @Query(value = "SELECT * FROM travel_stoke WHERE travel_id = :travelId", nativeQuery = true)
    List<TravelStokeEntity> getTravelStokeEntitiesByTravelId(String travelId);
}
