package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.TravelSearchResult;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class TravelSearchMapper implements RowMapper<TravelSearchResult> {
    @Override
    public TravelSearchResult mapRow(ResultSet resultSet, int i) throws SQLException {
        TravelSearchResult travelSearchResult =
                new TravelSearchResult();

        travelSearchResult.setTravelId(resultSet.getString("id"));
        travelSearchResult.setTravelTitle(resultSet.getString("title"));
        travelSearchResult.setTravelScore(resultSet.getDouble("score"));
        travelSearchResult.setTravelPrice(resultSet.getDouble("price"));
        travelSearchResult.setVisitNum(resultSet.getInt("visit_num"));
        travelSearchResult.setKind(resultSet.getString("kind"));
        travelSearchResult.setTravelDate(resultSet.getDate("travel_date"));
        travelSearchResult.setImageAddress(resultSet.getString("imageAddress"));

        return travelSearchResult;
    }
}
