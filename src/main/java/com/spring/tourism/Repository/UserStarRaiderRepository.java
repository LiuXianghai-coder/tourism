package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserStarRaiderEntity;
import com.spring.tourism.Entity.UserStarRaiderEntityPK;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserStarRaiderRepository
        extends CrudRepository<UserStarRaiderEntity, UserStarRaiderEntityPK> {
    UserStarRaiderEntity getUserStarRaiderEntityByUserIdAndRaiderId(@Param("userId") String userId,
                                                                    @Param("raiderId") String raiderId);

    @Modifying
    @Transactional
    @Query(value = "DELETE FROM user_star_raider WHERE " +
            "raider_id = :raiderId AND user_id = :userId", nativeQuery = true)
    void deleteUserStarRaiderEntityByRaiderIdAndUserIdUseQuery(@Param("raiderId") String raiderId,
                                                               @Param("userId") String userId);
}