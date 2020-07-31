package com.spring.tourism.Entity;

import javax.persistence.*;

@Entity
@Table(name = "raider_detail")
@IdClass(RaiderDetailPK.class)
public class RaiderDetail {
    @Id
    @Column(name = "raider_id")
    private String raiderId;

    @Id
    @Column(name = "raider_step")
    private Integer raiderStep;

    @Basic
    @Column(name = "font_size")
    private Short fontSize;

    @Basic
    @Column(name = "raider_detail")
    private String detail;

    @Override
    public String toString() {
        return "raiderId: " + raiderId + "\traiderStep: " + raiderStep
                + "\tfontSize: " + fontSize + "\tdetail: " + detail;
    }

    public Short getFontSize() {
        return fontSize;
    }

    public void setFontSize(Short fontSize) {
        this.fontSize = fontSize;
    }

    public String getDetail() {
        return detail;
    }

    public void setDetail(String detail) {
        this.detail = detail;
    }

    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    public Integer getRaiderStep() {
        return raiderStep;
    }

    public void setRaiderStep(Integer raiderStep) {
        this.raiderStep = raiderStep;
    }
}
