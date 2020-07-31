package com.spring.tourism.Repository;

import com.spring.tourism.DAO.TravelSimpleDAO;
import com.spring.tourism.Entity.TravelSimpleEntity;
import com.spring.tourism.RowMapper.TravelSimpleRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.List;

@Repository
public class TravelSimpleImpl implements TravelSimpleDAO {
    @Resource
    private JdbcTemplate jdbcTemplate;

    @Override
    public TravelSimpleEntity getTravelSimpleEntityById(String travelId) {
        try {
            String sql = "SELECT id AS travel_id, title AS travel_title, score AS travel_score,\n" +
                    "       price AS travel_price, visit_num AS num_people,\n" +
                    "       start_date AS travel_date, kind AS kind_name, imageAddress AS image_address\n" +
                    "FROM get_travel_simple() WHERE id=?";
            return this.jdbcTemplate.
                    queryForObject(sql, new Object[]{travelId}, new TravelSimpleRowMapper());
        } catch (Exception e) {
            return null;
        }
    }

    @Override
    public List<TravelSimpleEntity> getTravelSimpleEntityList(int start, int size) {
        try {
            if (start <=0 || size <= 0 ) return new ArrayList<>();

            String sql = "SELECT id AS travel_id, title AS travel_title, score AS travel_score,\n" +
                    "       price AS travel_price, visit_num AS num_people,\n" +
                    "       start_date AS travel_date, kind AS kind_name, imageAddress AS image_address\n" +
                    "FROM get_travel_simple() LIMIT ? OFFSET ?";
            return this.jdbcTemplate.query(sql, new Object[]{size, start},
                    new TravelSimpleRowMapper());
        } catch (Exception e) {
            return null;
        }
    }
}
