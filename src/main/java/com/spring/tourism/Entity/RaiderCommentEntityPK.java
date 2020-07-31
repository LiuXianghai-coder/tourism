package com.spring.tourism.Entity;

import javax.persistence.Basic;
import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class RaiderCommentEntityPK implements Serializable {
    private String userId;
    private String raiderId;
    private Integer commentId;

    @Column(name = "user_id")
    @Id
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Column(name = "raider_id")
    @Id
    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    @Basic
    @Column(name = "comment_id")
    public Integer getCommentId() {
        return commentId;
    }

    public void setCommentId(Integer commentId) {
        this.commentId = commentId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        RaiderCommentEntityPK that = (RaiderCommentEntityPK) o;

        if (!Objects.equals(userId, that.userId)) return false;
        return Objects.equals(raiderId, that.raiderId);
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (raiderId != null ? raiderId.hashCode() : 0);
        return result;
    }
}
