package com.spring.tourism.DAO;

import com.spring.tourism.Entity.UserStarRaiderEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.lang.NonNull;

public interface RaiderStarDAO {
    void setJdbcTemplate(@NonNull JdbcTemplate jdbcTemplate);

    void saveRaiderStarEntity(UserStarRaiderEntity userStarRaiderEntity);
}
