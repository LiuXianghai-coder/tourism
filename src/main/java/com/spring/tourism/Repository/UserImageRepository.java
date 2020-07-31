package com.spring.tourism.Repository;

import com.spring.tourism.Entity.UserImageEntity;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserImageRepository extends CrudRepository<UserImageEntity, String> {
    @Modifying
    @Transactional
    @Query(value = "INSERT INTO user_image(user_id, image_address) " +
            "VALUES(:userId, :imageAddress) ON CONFLICT(user_id) DO UPDATE SET image_address=:imageAddress",
            nativeQuery = true)
    void addUserImage(@Param("userId") String userId, @Param("imageAddress") String imageAddress);

    UserImageEntity getUserImageEntityByUserId(@Param("userId") String userId);
}
