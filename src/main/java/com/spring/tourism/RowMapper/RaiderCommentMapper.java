package com.spring.tourism.RowMapper;

import com.spring.tourism.Entity.RaiderCommentEntity;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class RaiderCommentMapper implements RowMapper<RaiderCommentEntity> {
    @Override
    public RaiderCommentEntity mapRow(ResultSet resultSet, int i) throws SQLException {
        RaiderCommentEntity raiderCommentEntity = new RaiderCommentEntity();

        raiderCommentEntity.setUserId(resultSet.getString("user_id"));
        raiderCommentEntity.setCommentDate(resultSet.getDate("comment_date"));
        raiderCommentEntity.setRaiderId(resultSet.getString("raider_id"));
        raiderCommentEntity.setCommentId(resultSet.getInt("comment_id"));
        raiderCommentEntity.setCommentContent(resultSet.getString("comment_content"));

        return raiderCommentEntity;
    }
}
