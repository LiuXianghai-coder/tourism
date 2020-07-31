package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.TravelSimpleEntity;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class TravelSimpleRowMapper implements RowMapper<TravelSimpleEntity> {
    @Override
    public TravelSimpleEntity mapRow(ResultSet resultSet, int i) throws SQLException {
        TravelSimpleEntity travelSimpleEntity = new TravelSimpleEntity();

        travelSimpleEntity.setTravelId(resultSet.getString("travel_id"));
        travelSimpleEntity.setTravelTitle(resultSet.getString("travel_title"));
        travelSimpleEntity.setTravelScore(resultSet.getDouble("travel_score"));
        travelSimpleEntity.setTravelPrice(resultSet.getDouble("travel_price"));
        travelSimpleEntity.setVisitNum(resultSet.getInt("num_people"));
        travelSimpleEntity.setTravelDate(resultSet.getDate("travel_date"));
        travelSimpleEntity.setKindName(resultSet.getString("kind_name"));
        travelSimpleEntity.setImageAddress(resultSet.getString("image_address"));

        return travelSimpleEntity;
    }
}
