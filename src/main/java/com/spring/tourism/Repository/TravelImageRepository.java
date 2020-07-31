package com.spring.tourism.Repository;

import com.spring.tourism.Entity.TravelImageEntity;
import com.spring.tourism.Entity.TravelImageEntityPK;
import org.springframework.data.repository.CrudRepository;

import java.util.List;

public interface TravelImageRepository
        extends CrudRepository<TravelImageEntity, TravelImageEntityPK> {
    List<TravelImageEntity> getTravelImageEntitiesByTravelId(String travelId);
}
