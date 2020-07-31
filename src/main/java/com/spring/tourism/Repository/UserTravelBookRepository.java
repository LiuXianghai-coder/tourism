package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserTravelBookingEntity;
import com.spring.tourism.Entity.UserTravelBookingEntityPK;
import org.springframework.data.repository.CrudRepository;

public interface UserTravelBookRepository extends
        CrudRepository<UserTravelBookingEntity, UserTravelBookingEntityPK> {
}
