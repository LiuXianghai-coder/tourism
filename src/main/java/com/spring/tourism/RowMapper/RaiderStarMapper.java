package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.UserStarRaiderEntity;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class RaiderStarMapper implements RowMapper<UserStarRaiderEntity> {
    @Override
    public UserStarRaiderEntity mapRow(ResultSet resultSet, int i) throws SQLException {
        UserStarRaiderEntity userStarRaiderEntity =
                new UserStarRaiderEntity();

        userStarRaiderEntity.setUserId(resultSet.getString("user_id"));
        userStarRaiderEntity.setRaiderId(resultSet.getString("raider_id"));
        userStarRaiderEntity.setStarDate(resultSet.getDate("star_date"));

        return userStarRaiderEntity;
    }
}
