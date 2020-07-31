package com.spring.tourism.Repository;

import com.spring.tourism.DAO.RaiderCommentDAO;
import com.spring.tourism.Entity.RaiderCommentEntity;
import com.spring.tourism.RowMapper.RaiderCommentMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.lang.NonNull;

import java.util.ArrayList;
import java.util.List;

public class RaiderCommentImpl implements RaiderCommentDAO {
    private final JdbcTemplate jdbcTemplate;

    public RaiderCommentImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public List<RaiderCommentEntity> getRaiderCommentEntityByRaiderId(String raiderId) {
        try {
            String sql = "SELECT * FROM raider_comment WHERE raider_id = ?";
            return jdbcTemplate.query(sql, new Object[]{raiderId}, new RaiderCommentMapper());
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    @Override
    public void insertRaiderCommentEntity(RaiderCommentEntity raiderCommentEntity) {
        try {
            String sql = "INSERT INTO raider_comment(user_id, raider_id, comment_content," +
                    " comment_date) VALUES (?, ?, ?, ?)";

            jdbcTemplate.update(sql, raiderCommentEntity.getUserId(), raiderCommentEntity.getRaiderId(),
                    raiderCommentEntity.getCommentContent(), raiderCommentEntity.getCommentDate());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public List<RaiderCommentEntity> getRaiderCommentByRaiderIdAndUserId(@NonNull String raiderId,
                                                                         @NonNull String userId) {
        try {
            if (raiderId.trim().length() == 0) {
                return new ArrayList<>();
            }

            if (userId.trim().length() == 0) {
                return new ArrayList<>();
            }

            String sql = "SELECT * FROM raider_comment WHERE raider_id=? AND user_id=?";
            return this.jdbcTemplate.query(sql,
                    new Object[]{raiderId, userId}, new RaiderCommentMapper());
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    @Override
    public void removeRaiderCommentByRaiderIdAndUserIdAndCommentId(String raiderId,
                                                                   String userId,
                                                                   Integer commentId) {
        try {
            if (raiderId.trim().length() == 0) {
               throw new IllegalArgumentException("delete raider comment raiderId valid length is 0");
            }

            if (commentId <= Integer.MIN_VALUE || commentId >= Integer.MAX_VALUE) {
                throw new IllegalArgumentException("delete raider comment commentId parameter error");
            }

            if (userId == null || userId.trim().length() == 0) {
                throw new IllegalArgumentException("delete from raider comment userId valid length is 0");
            }

            String sql = "DELETE FROM raider_comment WHERE raider_id = ? AND user_id = ? AND comment_id = ?";
            this.jdbcTemplate.update(sql, raiderId, userId, commentId);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
