package com.spring.tourism.DAO;

import com.spring.tourism.Entity.RaiderEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.lang.NonNull;

public interface RaiderDAO {
    void setJdbcTemplate(@NonNull JdbcTemplate jdbcTemplate);

    void saveRaiderEntity(RaiderEntity raiderEntity);
}
