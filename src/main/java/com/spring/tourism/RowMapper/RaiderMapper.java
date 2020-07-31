package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.RaiderEntity;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class RaiderMapper implements RowMapper<RaiderEntity> {
    @Override
    public RaiderEntity mapRow(ResultSet resultSet, int i) throws SQLException {
        RaiderEntity raiderEntity = new RaiderEntity();

        raiderEntity.setRaiderId(resultSet.getString("raider_id"));
        raiderEntity.setRaiderTitle(resultSet.getString("raider_title"));
        raiderEntity.setRaiderDate(resultSet.getDate("raider_date"));
        raiderEntity.setStars(resultSet.getInt("stars"));
        raiderEntity.setVisits(resultSet.getInt("visits"));
        raiderEntity.setDateBetween(resultSet.getLong("date_between"));

        return raiderEntity;
    }
}
