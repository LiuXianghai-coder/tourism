package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserEntity;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserRepository extends CrudRepository<UserEntity, String> {
    UserEntity getUserEntityByUserIdAndUserPassword(String userId, String userPassword);
    UserEntity getUserEntityByUserId(String userId);

    @Modifying
    @Transactional
    @Query(value = "UPDATE \"user\" SET user_password = :userPassword WHERE user_id = :userId", nativeQuery = true)
    void updateUserPassword(@Param("userPassword") String userPassword,
                            @Param("userId") String userId);

    @Modifying
    @Transactional
    @Query(value = "UPDATE \"user\" SET user_name = :userName WHERE user_id = :userId", nativeQuery = true)
    void updateUserName(@Param("userName") String userName,
                        @Param("userId") String userId);
}
