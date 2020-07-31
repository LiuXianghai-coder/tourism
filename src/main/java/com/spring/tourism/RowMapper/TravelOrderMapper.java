package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.TravelOrder;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class TravelOrderMapper implements RowMapper<TravelOrder> {
    @Override
    public TravelOrder mapRow(ResultSet resultSet, int i) throws SQLException {
        TravelOrder travelOrder = new TravelOrder();

        travelOrder.setUserId(resultSet.getString("user_id"));
        travelOrder.setBookDate(resultSet.getDate("book_date"));
        travelOrder.setTravelId(resultSet.getString("travel_id"));
        travelOrder.setTravelTitle(resultSet.getString("travel_title"));
        travelOrder.setTravelScore(resultSet.getFloat("travel_score"));
        travelOrder.setVisitsNum(resultSet.getInt("num_people"));
        travelOrder.setTravelDate(resultSet.getDate("travel_date"));
        travelOrder.setTravelPrice(resultSet.getDouble("travel_price"));
        travelOrder.setImageAddress(resultSet.getString("image_address"));

        return travelOrder;
    }
}
