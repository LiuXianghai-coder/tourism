package com.spring.tourism.Repository;

import com.spring.tourism.DAO.RaiderStarDAO;
import com.spring.tourism.Entity.UserStarRaiderEntity;
import org.springframework.jdbc.core.JdbcTemplate;

public class RaiderStarImpl implements RaiderStarDAO {
    private JdbcTemplate jdbcTemplate;

    public RaiderStarImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void setJdbcTemplate(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void saveRaiderStarEntity(UserStarRaiderEntity userStarRaiderEntity) {
        if (userStarRaiderEntity == null) return;

        try {
            String sql = "INSERT INTO user_star_raider(user_id, raider_id, star_date) VALUES (?, ?, ?)";

            this.jdbcTemplate.update(sql, userStarRaiderEntity.getUserId(),
                    userStarRaiderEntity.getRaiderId(), userStarRaiderEntity.getStarDate());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
