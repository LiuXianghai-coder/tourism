package com.spring.tourism.Repository;

import com.spring.tourism.DAO.TravelScheduleDAO;
import com.spring.tourism.Entity.TravelStokeEntity;
import com.spring.tourism.RowMapper.TravelStokeMapper;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.ArrayList;
import java.util.List;

public class TravelScheduleImpl implements TravelScheduleDAO {
    private JdbcTemplate jdbcTemplate;

    public TravelScheduleImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public List<TravelStokeEntity> getTravelStokeByTravelId(String travelId) {
        try {
            if (travelId == null || travelId.trim().length() == 0) {
                return new ArrayList<>();
            }

            String sql = "SELECT * FROM (\n" +
                    "\tSELECT * FROM travel_stoke WHERE travel_id=? \n" +
                    "\tORDER BY travel_step_id) AS temp";

            return  jdbcTemplate.query(sql, new Object[]{travelId}, new TravelStokeMapper());
        } catch (Exception e) {
            return null;
        }
    }
}
