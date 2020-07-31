package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserSaveRaiderEntity;
import com.spring.tourism.Entity.UserSaveRaiderEntityPK;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserSaveRaiderRepository extends
        CrudRepository<UserSaveRaiderEntity, UserSaveRaiderEntityPK> {
    UserSaveRaiderEntity getUserSaveRaiderEntityByRaiderIdAndUserId(@Param("raiderId") String raiderId,
                                                                    @Param("userId") String userId);

    @Modifying
    @Transactional
    @Query(value = "DELETE FROM user_save_raider WHERE raider_id = :raiderId AND user_id = :userId",
            nativeQuery = true)
    void deleteUserSaveRaiderEntityByRaiderIdAndAndUserIdUseQuery(@Param("raiderId") String raiderId,
                                                                  @Param("userId") String userId);
}
