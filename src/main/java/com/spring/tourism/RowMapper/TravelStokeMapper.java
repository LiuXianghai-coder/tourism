package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.TravelStokeEntity;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class TravelStokeMapper implements RowMapper<TravelStokeEntity> {
    @Override
    public TravelStokeEntity mapRow(ResultSet resultSet, int i) throws SQLException {
        TravelStokeEntity travelStokeEntity = new TravelStokeEntity();
        travelStokeEntity.setTravelId(resultSet.getString("travel_id"));
        travelStokeEntity.setTravelStepId(resultSet.getShort("travel_step_id"));
        travelStokeEntity.setTravelCopyId(resultSet.getShort("travel_copy_id"));
        travelStokeEntity.setTravelStepDetail(resultSet.getString("travel_step_detail"));

        return travelStokeEntity;
    }
}
