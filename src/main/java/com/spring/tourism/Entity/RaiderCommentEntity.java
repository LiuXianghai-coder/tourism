package com.spring.tourism.Entity;

import javax.persistence.*;
import java.sql.Date;
import java.util.Objects;

@Entity
@Table(name = "raider_comment", schema = "public", catalog = "travel")
@IdClass(RaiderCommentEntityPK.class)
public class RaiderCommentEntity {
    private String userId;
    private String raiderId;
    private Integer commentId;
    private String commentContent;
    private Date commentDate;

    @Id
    @Column(name = "user_id")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Id
    @Column(name = "raider_id")
    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    @Basic
    @Column(name = "commment_id")
    public Integer getCommentId() {
        return commentId;
    }

    public void setCommentId(Integer commentId) {
        this.commentId = commentId;
    }

    @Basic
    @Column(name = "comment_content")
    public String getCommentContent() {
        return commentContent;
    }

    public void setCommentContent(String commentContent) {
        this.commentContent = commentContent;
    }

    @Basic
    @Column(name = "comment_date")
    public Date getCommentDate() {
        return commentDate;
    }

    public void setCommentDate(Date commentDate) {
        this.commentDate = commentDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        RaiderCommentEntity that = (RaiderCommentEntity) o;

        if (!Objects.equals(userId, that.userId)) return false;
        if (!Objects.equals(raiderId, that.raiderId)) return false;
        if (!Objects.equals(commentContent, that.commentContent))
            return false;
        if (!Objects.equals(commentDate, that.commentDate)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (raiderId != null ? raiderId.hashCode() : 0);
        result = 31 * result + (commentContent != null ? commentContent.hashCode() : 0);
        result = 31 * result + (commentDate != null ? commentDate.hashCode() : 0);
        return result;
    }
}
