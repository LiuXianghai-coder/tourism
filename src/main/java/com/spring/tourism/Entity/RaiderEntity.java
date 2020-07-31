package com.spring.tourism.Entity;

import javax.persistence.*;
import java.sql.Date;

@Entity
@Table(name = "raider")
public class RaiderEntity {
    @Id
    @Column(name = "raider_id")
    private String raiderId;

    @Basic
    @Column(name = "raider_title")
    private String raiderTitle;

    @Basic
    @Column(name = "stars")
    private Integer stars;

    @Basic
    @Column(name = "visits")
    private Integer visits;

    @Basic
    @Column(name = "raider_date")
    private Date raiderDate;

    private Long dateBetween;

    public RaiderEntity() {
        dateBetween = 0L;
    }

    public Long getDateBetween() {
        return dateBetween;
    }

    public void setDateBetween(Long dateBetween) {
        this.dateBetween = dateBetween;
    }

    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    public String getRaiderTitle() {
        return raiderTitle;
    }

    public void setRaiderTitle(String raiderTitle) {
        this.raiderTitle = raiderTitle;
    }

    public Integer getStars() {
        return stars;
    }

    public void setStars(Integer stars) {
        this.stars = stars;
    }

    public Integer getVisits() {
        return visits;
    }

    public void setVisits(Integer visits) {
        this.visits = visits;
    }

    public Date getRaiderDate() {
        return raiderDate;
    }

    public void setRaiderDate(Date raiderDate) {
        this.raiderDate = raiderDate;
    }

    @Override
    public String toString() {
        return "raiderId: " + raiderId + "\traiderTitle: " +
                raiderTitle + "\traiderStars: " + stars +
                "\tvisits: " + visits + "\traiderDate: " + raiderDate
                + "\tdateBetween: " + dateBetween;
    }
}
