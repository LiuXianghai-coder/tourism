package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserRaiderEntity;
import com.spring.tourism.Entity.UserRaiderEntityPK;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserRaiderRepository
        extends CrudRepository<UserRaiderEntity, UserRaiderEntityPK> {
    void deleteUserRaiderEntityByRaiderIdAndUserId(@Param("raiderId") String raiderId,
                                                   @Param("userId") String userId);

    @Modifying
    @Transactional
    @Query(value = "DELETE FROM user_raider WHERE raider_id = :raiderId AND user_id=:userId",
            nativeQuery = true)
    void deleteUserRaiderEntityUseQuery(@Param("raiderId") String raiderId,
                                        @Param("userId") String userId);
}
