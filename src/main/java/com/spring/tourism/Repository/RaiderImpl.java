package com.spring.tourism.Repository;

import com.spring.tourism.DAO.RaiderDAO;
import com.spring.tourism.Entity.RaiderEntity;
import org.springframework.jdbc.core.JdbcTemplate;

public class RaiderImpl implements RaiderDAO {
    private JdbcTemplate jdbcTemplate;

    @Override
    public void setJdbcTemplate(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void saveRaiderEntity(RaiderEntity raiderEntity) {
        if (raiderEntity == null ) {
            return;
        }

        try {
            String sql = "INSERT INTO raider(raider_id, raider_title, " +
                    "stars, visits, raider_date, date_between) " +
                    "VALUES (?, ?, ?, ?, ?)";
            jdbcTemplate.update(sql, raiderEntity.getRaiderId(), raiderEntity.getRaiderTitle(), raiderEntity.getStars(),
                    raiderEntity.getVisits(), raiderEntity.getRaiderDate(), raiderEntity.getDateBetween());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
