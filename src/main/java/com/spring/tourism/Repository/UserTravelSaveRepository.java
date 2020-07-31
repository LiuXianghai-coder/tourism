package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserTravelSaveEntity;
import com.spring.tourism.Entity.UserTravelSaveEntityPK;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

public interface UserTravelSaveRepository
        extends CrudRepository<UserTravelSaveEntity, UserTravelSaveEntityPK> {
    UserTravelSaveEntity getUserTravelSaveEntitiesByUserIdAndTravelId(@Param("userId") String userId,
                                                                      @Param("travelId") String travelId);
}
